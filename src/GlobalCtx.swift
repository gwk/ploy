// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


typealias SrcMapping = (pathString: String, lineIdx: Int, colIdx: Int, off: Int, frameName: String)
// note: `off` is the relative offset into the generated output string being written,
// e.g. if we are mapping a parenthesized symbol "(a)" then off=1.

typealias Line = (indent: Int, text:String, mapping: SrcMapping?)


class GlobalCtx {
  let dumpPath: Path
  let outFile: File
  let mapSend: FileHandle
  private var outLineIdx = 0
  private var outColIdx = 0
  private var conversions: Set<Conversion> = []
  private var constructors: Set<Type> = []
  lazy private var dumpFile: File = try! File(path: self.dumpPath, mode: .write, create: 0o644)

  init(dumpPath: Path, outFile: File, mapSend: FileHandle) {
    self.dumpPath = dumpPath
    self.outFile = outFile
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
      outFile.write(String(char: " ", count: diff) + l.text)
    } else { // new line.
      outLineIdx += 1
      outColIdx = l.indent
      outFile.write("\n" + String(char: " ", count: l.indent) + l.text)
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
    outFile.write(string)
    writeL()
  }

  func writeL() {
    outFile.write("\n")
    outLineIdx += 1
    outColIdx = 0
  }


  func emitConversion(conv: Conversion) {
    let orig = conv.orig
    let cast = conv.cast
    let em = Emitter(ctx: self)
    em.str(0, "const \(conv.hostName) = $o=> // \(conv)") // bling: $o: original.

    switch (orig.kind, cast.kind) {

    case (.prim, _) where orig == typeNever: // Never is treated by the type checker as compatible with any expected type.
      em.str(2, "{ throw new Error('PLOY RUNTIME ERROR: Never function returned.'); }")

    case (.sig(let o), .sig(let c)):
      emitSigToSig(em, castIdx: cast.globalIndex, orig: o, cast: c)

    case (.struct_(let o), .struct_(let c)):
      self.addConstructor(type: cast)
      emitStructToStruct(em, castIdx: cast.globalIndex, orig: o, cast: c)

    case (_, .union(let castMembers)):
      self.addConstructor(type: cast)
      emitConvToUnion(em, castIdx: cast.globalIndex, orig: orig, castMembers: castMembers)

    case (_, .prim) where cast == typeAny:
      em.str(2, "$o") // For now, no real conversion.

    default: fatalError("impossible conversion: \(conv)")
    }
    em.flush()
  }


  func emitSigToSig(_ em: Emitter, castIdx: Int,
   orig: (dom: Type, ret: Type), cast: (dom: Type, ret: Type)) {
    em.str(2, "$=>(") // converted value is a new function.
    var call = "$o($)"
    if let domConv = conversionFor(orig: cast.dom, cast: orig.dom) { // note: contravariant.
      call = "$o(\(domConv.hostName)($))" // convert outer argument to match original function.
    }
    if let retConv = conversionFor(orig: orig.ret, cast: cast.ret) { // convert return value of the original function.
      em.str(2, "\(retConv.hostName)(\(call))")
    } else {
      em.str(2, call)
    }
    em.append(")")
  }


  func emitStructToStruct(_ em: Emitter, castIdx: Int,
   orig: (posFields:[Type], labFields: [TypeLabField], variants: [TypeVariant]),
   cast: (posFields:[Type], labFields: [TypeLabField], variants: [TypeVariant])) {

    assert(cast.posFields.count + cast.labFields.count + cast.variants.count > 0) // conversion to nil is explictly disallowed.
    em.str(2, "(new $C\(castIdx)(") // bling: $C: constructor.

    let opc = orig.posFields.count
    let olc = orig.labFields.count
    var oi = 0

    for cType in cast.posFields {
      assertLT(oi, opc)
      let oType = orig.posFields[oi]
      let oName = posFieldHostName(index: oi)
      oi += 1
      if let fieldConv = conversionFor(orig: oType, cast: cType) {
        em.str(4, "\(fieldConv.hostName)($o.\(oName)),") // bling: $o: original.
      } else {
        em.str(4, "$o.\(oName),") // bling: $o: original.
      }
    }

    for c in cast.labFields {
      let oName: String
      let oType: Type
      if oi < opc {
        oType = orig.posFields[oi]
        oName = posFieldHostName(index: oi)
      } else {
        assert(oi < opc + olc)
        let o = orig.labFields[oi-opc]
        oType = o.type
        oName = o.hostName
      }
      oi += 1
      if let fieldConv = conversionFor(orig: oType, cast: c.type) {
        em.str(4, "\(fieldConv.hostName)($o.\(oName)),") // bling: $o: original.
      } else {
        em.str(4, "$o.\(oName),") // bling: $o: original.
      }
    }

    if !cast.variants.isEmpty {
      assert(!orig.variants.isEmpty)
      em.str(4, "$o.$v, $o[$o.$v]") // bling: $o: original; $v: variant tag.
    }
    em.append("));")
  }


  func emitConvToUnion(_ em: Emitter, castIdx: Int, orig: Type, castMembers: [Type]) {
    assert(!castMembers.isEmpty)

    switch orig.kind {

    case .union:
      em.str(2, "(new $C\(castIdx)($o.$u, $o.$m));") // since tag is just the type name, no conversion between tags is necessary.
      // bling: $C: constructor; $o: original; $u: union tag; $m: morph value.

    default:
      let tag = "'\(orig)'" // tag is just the type name; assume that no JS string literal escaping is necessary.
      em.str(2, "(new $C\(castIdx)(\(tag), $o));") // bling: $C: constructor; $o: original.
    }
  }


  func emitConstructor(type: Type) {
    let em = Emitter(ctx: self)
    em.str(0, "class $C\(type.globalIndex) {") // bling: $C: constructor.
    switch type.kind {

    case .struct_(let posFields, let labFields, let variants):
      emitStructConstructor(em, type: type, posFields: posFields, labFields: labFields, variants: variants)

    case .union(let members):
      emitUnionConstructor(em, type: type, members: members)

    default: fatalError("impossible constructor: \(type)")
    }
    em.append("}")
    em.flush()
  }


  func emitStructConstructor(_ em: Emitter, type: Type, posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant]) {
    assert(posFields.count + labFields.count + variants.count > 0) // nil is not constructed; represented by JS "null".

    let fieldParNames: [String] = posFields.indices.map{posFieldHostName(index: $0)} + labFields.map {$0.hostName}
    assertEq(fieldParNames.count, Set(fieldParNames).count)

    let fieldPars: String = fieldParNames.joined(separator: ", ")
    let variantPars = variants.isEmpty ? "" : "$v, $vv" // bling: $v: variant tag; $vv: variant value parameter.
    em.str(2, "constructor(\(fieldPars)\(variantPars)) { // \(type)")

    for i in posFields.indices {
      let n = posFieldHostName(index: i)
      em.str(4, "this.\(n) = \(n);")
    }
    for f in labFields {
      let n = f.hostName
      em.str(4, "this.\(n) = \(n);")
    }
    if !variants.isEmpty {
      em.str(4, "this.$v = $v; this[$v] = $vv;") // bling: $v: variant tag; $vv: variant value parameter.
    }
    em.append("}")
  }


  func emitUnionConstructor(_ em: Emitter, type: Type, members: [Type]) {
    assert(!members.isEmpty)
    em.str(2, "constructor($u, $m) { // \(type)") // bling: $u: union tag; $m: morph value.
    em.str(4, "this.$u = $u; this.$m = $m") // bling: $u: union tag; $m: morph value.
    em.append("}")
  }


  func dump<T:Encodable>(object:T) {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(object)
    dumpFile.write(data: data)
    dumpFile.write("\n")
  }
}
