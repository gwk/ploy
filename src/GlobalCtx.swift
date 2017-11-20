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
  var outLineIdx = 0
  var outColIdx = 0
  var conversions: Set<Conversion> = []
  var constructors: Set<Type> = []

  init(mainPath: Path, file: File, mapSend: FileHandle) {
    self.mainPath = mainPath
    self.file = file
    self.mapSend = mapSend
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

  func emitConversions() {
    var convs = conversions.sorted()
    var i = 0
    while i < convs.count {
      let conv = convs[i]
      i += 1
      let orig = conv.orig
      let cast = conv.cast
      let em = Emitter(ctx: self)
      em.str(0, "const \(conv.hostName) = $=> ")
      switch (orig.kind, cast.kind) {

      case (.prim, _) where orig == typeNever: // Never is treated by the type checker as compatible with any expected type.
        em.append("{ throw new Error('PLOY RUNTIME ERROR: Never function returned.'); };")

      case (.struct_(let o), .struct_(let c)):
        self.constructors.insert(cast)
        em.append("(new $S\(cast.globalIndex)( // \(conv)") // bling: $S: struct constructor.
        emitStructToStruct(em, convs: &convs, conv: conv, orig: o, cast: c)
        em.append("));")

      default: fatalError("impossible conversion: \(conv)")
      }
      em.flush()
    }
  }

  func emitStructToStruct(_ em: Emitter, convs: inout [Conversion], conv: Conversion,
   orig: (fields: [TypeField], variants: [TypeField]),
   cast: (fields: [TypeField], variants: [TypeField])) {
    assert(cast.fields.count + cast.variants.count > 0) // conversion to nil is explictly disallowed.
    assert(orig.fields.count == cast.fields.count)
    for (i, (o, c)) in zip(orig.fields, cast.fields).enumerated() {
      let oName = o.hostName(index: i)
      if o.type != c.type {
        let fieldConv = Conversion(orig: o.type, cast: c.type)
        if !conversions.contains(fieldConv) {
          conversions.insert(fieldConv)
          convs.append(fieldConv)
        }
        em.str(2, "\(fieldConv.hostName)($.\(oName)),")
      } else {
        em.str(2, "$.\(oName),")
      }
    }
    if !cast.variants.isEmpty {
      assert(!orig.variants.isEmpty)
      em.str(2, "$.$t, $.$m") // bling: $t: morph tag; $m: morph value.
    }
  }


  func emitConstructors() {
    for type in constructors.sorted() {
      let em = Emitter(ctx: self)
      em.str(0, "class $S\(type.globalIndex) {")
      switch type.kind {

      case .struct_(let fields, let variants):
        emitStructConstructor(em, type: type, fields: fields, variants: variants)

      default: fatalError("impossible constructor: \(type)")
      }
      em.append("}")
      em.flush()
    }
  }

  func emitStructConstructor(_ em: Emitter, type: Type, fields: [TypeField], variants: [TypeField]) {
    assert(fields.count + variants.count > 0) // nil is not constructed; represented by JS "null".
    let fieldParNames: [String] = fields.enumerated().map {$1.hostName(index: $0)}
    let fieldPars: String = fieldParNames.joined(separator: ", ")
    let variantPars = variants.isEmpty ? "" : "$t, $m" // bling: $t: morph tag; $m: morph value.
    em.append(" constructor(\(fieldPars)\(variantPars)) { // \(type)") // bling: $S: struct constructor.
    for (i, f) in fields.enumerated() {
      let n = f.hostName(index: i)
      em.str(2, "this.\(n) = \(n);")
    }
    if !variants.isEmpty {
      em.str(2, "this.$t = $t; this.$m = $m;") // bling: $t: morph tag; $m: morph value.
    }
    em.append("}")
  }
}
