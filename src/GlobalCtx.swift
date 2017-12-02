// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


typealias SrcMapping = (pathString: String, lineIdx: Int, colIdx: Int, off: Int, frameName: String)
// note: `off` is the relative offset into the generated output string being written,
// e.g. if we are mapping  a parenthesized symbol "(a)" then off=1.

typealias Line = (indent: Int, text:String, mapping: SrcMapping?)


class GlobalCtx {
  let mainPath: Path
  let file: File
  let mapSend: FileHandle
  private var outLineIdx = 0
  private var outColIdx = 0
  private var conversions: Set<Conversion> = []
  private var constructors: Set<Type> = []

  init(mainPath: Path, file: File, mapSend: FileHandle) {
    self.mainPath = mainPath
    self.file = file
    self.mapSend = mapSend
  }

  func conversionFor(orig: Type, cast: Type) -> Conversion? {
    if orig == cast { return nil }
    let conv = Conversion(orig: orig, cast: cast)
    if !conversions.contains(conv) {
      conversions.insert(conv)
      emitConversion(conv: conv)
    }
    return conv
  }

  func addConstructor(type: Type) {
    if !constructors.contains(type) {
      constructors.insert(type)
      emitConstructor(type: type)
    }
  }

  func writeMap(_ m: SrcMapping) {
    mapSend.write("\(m.pathString) \(m.frameName) \(m.lineIdx) \(m.colIdx) \(outLineIdx) \(outColIdx + m.off)\n")
  }

  func write(line l: Line) {
    assert(!l.text.containsNewline)
    let diff = l.indent - outColIdx
    if diff >= 0 { // inline.
      outColIdx += diff
      file.write(String(char: " ", count: diff) + l.text)
    } else { // new line.
      outLineIdx += 1
      outColIdx = l.indent
      file.write("\n" + String(char: " ", count: l.indent) + l.text)
    }
    if let mapping = l.mapping {
      writeMap(mapping)
    }
    outColIdx += l.text.count
  }

  func writeL(_ string: String, _ mapping: SrcMapping? = nil) {
    assert(!string.containsNewline)
    assert(outColIdx == 0)
    if let mapping = mapping { writeMap(mapping) }
    file.write(string)
    writeL()
  }

  func writeL() {
    file.write("\n")
    outLineIdx += 1
    outColIdx = 0
  }


  func emitConversion(conv: Conversion) {
    let orig = conv.orig
    let cast = conv.cast
    var shouldEmitCastConstructor = true
    let em = Emitter(ctx: self)
    em.str(0, "const \(conv.hostName) = $o=> // \(conv)") // bling: $o: original.

    switch (orig.kind, cast.kind) {

    case (.prim, _) where orig == typeNever: // Never is treated by the type checker as compatible with any expected type.
      em.str(2, "{ throw new Error('PLOY RUNTIME ERROR: Never function returned.'); }")
      shouldEmitCastConstructor = false

    case (.struct_(let o), .struct_(let c)):
      emitStructToStruct(em, castIdx: cast.globalIndex, orig: o, cast: c)

    case (_, .any(let castMembers)):
      emitConvToUnion(em, castIdx: cast.globalIndex, orig: orig, castMembers: castMembers)

    default: fatalError("impossible conversion: \(conv)")
    }

    em.flush()
    if shouldEmitCastConstructor { self.addConstructor(type: cast) }
  }


  func emitStructToStruct(_ em: Emitter, castIdx: Int,
   orig: (fields: [TypeField], variants: [TypeField]),
   cast: (fields: [TypeField], variants: [TypeField])) {
    assert(cast.fields.count + cast.variants.count > 0) // conversion to nil is explictly disallowed.
    assert(orig.fields.count == cast.fields.count)
    em.str(2, "(new $C\(castIdx)(") // bling: $C: constructor.
    for (i, (o, c)) in zip(orig.fields, cast.fields).enumerated() {
      let oName = o.hostName(index: i)
      if let fieldConv = conversionFor(orig: o.type, cast: c.type) {
        em.str(4, "\(fieldConv.hostName)($o.\(oName)),") // bling: $o: original.
      } else {
        em.str(4, "$o.\(oName),") // bling: $o: original.
      }
    }
    if !cast.variants.isEmpty {
      assert(!orig.variants.isEmpty)
      em.str(4, "$o.$v, $o.$m") // bling: $o: original; $v: variant tag; $m: morph value.
    }
    em.append("));")
  }


  func emitConvToUnion(_ em: Emitter, castIdx: Int, orig: Type, castMembers: [Type]) {
    assert(!castMembers.isEmpty)

    switch orig.kind {

    case .any(let origMembers):
      let tableName = "$ct\(orig.globalIndex)_\(castIdx)" // bling: $ct: union tag table.
      em.str(2, "(new $C\(castIdx)(\(tableName)[$o.$u], $o.$m));")
      // bling: $C: constructor; $o: original; $u: union variant tag; $m: morph value.
      let table = origMembers.map { castMembers.index(of: $0)! }
      let indices = table.descriptions.joined(separator: ",")
      em.str(0, "const \(tableName) = [\(indices)];")

    default:
      guard let tag = castMembers.index(of: orig) else { fatalError("orig type `\(orig)` is not member of union: \(castMembers)") }
      em.str(2, "(new $C\(castIdx)(\(tag), $o));") // bling: $C: constructor; $o: original.
    }
  }


  func emitConstructor(type: Type) {
    let em = Emitter(ctx: self)
    em.str(0, "class $C\(type.globalIndex) {") // bling: $C: constructor.
    switch type.kind {

    case .struct_(let fields, let variants):
      emitStructConstructor(em, type: type, fields: fields, variants: variants)

    case .any(let members):
      emitUnionConstructor(em, type: type, members: members)

    default: fatalError("impossible constructor: \(type)")
    }
    em.append("}")
    em.flush()
  }


  func emitStructConstructor(_ em: Emitter, type: Type, fields: [TypeField], variants: [TypeField]) {
    assert(fields.count + variants.count > 0) // nil is not constructed; represented by JS "null".
    let fieldParNames: [String] = fields.enumerated().map {$1.hostName(index: $0)}
    let fieldPars: String = fieldParNames.joined(separator: ", ")
    let variantPars = variants.isEmpty ? "" : "$v, $m" // bling: $v: variant tag; $m: morph value.
    em.str(2, "constructor(\(fieldPars)\(variantPars)) { // \(type)")
    for (i, f) in fields.enumerated() {
      let n = f.hostName(index: i)
      em.str(4, "this.\(n) = \(n);")
    }
    if !variants.isEmpty {
      em.str(4, "this.$v = $v; this.$m = $m;") // bling: $v: variant tag; $m: morph value.
    }
    em.append("}")
  }


  func emitUnionConstructor(_ em: Emitter, type: Type, members: [Type]) {
    assert(!members.isEmpty)
    em.str(2, "constructor($u, $m) { // \(type)") // bling: $u: union variant tag; $m: morph value.
    em.str(4, "this.$u = $u; this.$m = $m") // bling: $u: union tag; $m: morph value.
    em.append("}")
  }
}
