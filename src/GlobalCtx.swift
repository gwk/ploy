// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


typealias SrcMapping = (path: String, line: Int, col: Int, off: Int, frameName: String)

typealias Line = (indent: Int, text:String, mapping: SrcMapping?)

let utf16Newline = "\n".utf16[String.UTF16View.Index(0)]

class GlobalCtx {
  let mainPath: String
  let file: OutFile
  let mapSend: FileHandle
  var line = 0
  var col = 0
  var conversions: Set<Conversion> = []

  init(mainPath: String, file: OutFile, mapSend: FileHandle) {
    self.mainPath = mainPath
    self.file = file
    self.mapSend = mapSend
  }

  func writeMap(_ m: SrcMapping) {
    assert(!m.path.isEmpty)
    mapSend.write("\(m.path) \(m.frameName) \(m.line) \(m.col) \(line) \(col + m.off)\n")
  }

  func write(line l: Line) {
    assert(!l.text.utf16.contains(utf16Newline)) // assuming utf16 is the underlying storage, this should be quick.
    let diff = l.indent - col
    if diff >= 0 { // inline.
      col += diff
      file.write(String(char: " ", count: diff) + l.text)
    } else { // new line.
      line += 1
      col = l.indent
      file.write("\n" + String(char: " ", count: l.indent) + l.text)
    }
    if let mapping = l.mapping {
      writeMap(mapping)
    }
    col += l.text.characters.count
  }

  func writeL(_ string: String, _ mapping: SrcMapping? = nil) {
    assert(!string.utf16.contains(utf16Newline)) // assuming utf16 is the underlying storage, this should be quick.
    assert(col == 0)
    if let mapping = mapping { writeMap(mapping) }
    file.write(string)
    writeL()
  }

  func writeL() {
    file.write("\n")
    line += 1
    col = 0
  }

  func addConversion(_ conv: Conversion) {
    conversions.insert(conv)
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
      switch (orig.kind, cast.kind) {

      case (.prim, _) where orig == typeNever:
        em.str(0, "let \(conv.hostName) = $=>{ throw new Error('PLOY RUNTIME ERROR: Never function returned.'); };")

      case (.struct_(let orig), .struct_(let cast)):
        emitStructToStruct(em, convs: &convs, conv: conv, orig: orig, cast: cast)

      default: fatalError("impossible conversion: \(conv)")
      }
      em.flush()
    }
  }

  func emitStructToStruct(_ em: Emitter, convs: inout [Conversion], conv: Conversion,
   orig: (fields: [TypeField], variants: [TypeField]),
   cast: (fields: [TypeField], variants: [TypeField])) {
    em.str(0, "let \(conv.hostName) = $=>({ // \(conv)")
    assert(cast.fields.count + cast.variants.count > 0) // conversion to nil is explictly disallowed.
    assert(orig.fields.count == cast.fields.count)
    for (i, (o, c)) in zip(orig.fields, cast.fields).enumerated() {
      let oName = o.hostName(index: i)
      let cName = c.hostName(index: i)
      if o.type != c.type {
        let fieldConv = Conversion(orig: o.type, cast: c.type)
        if !conversions.contains(fieldConv) {
          conversions.insert(fieldConv)
          convs.append(fieldConv)
        }
        em.str(2, "\(cName): \(fieldConv.hostName)($.\(oName)),")
      } else {
        em.str(2, "\(cName): $.\(oName),")
      }
    }
    if !cast.variants.isEmpty {
      assert(!orig.variants.isEmpty)
      em.str(2, "$t: $.$t,") // bling: $t: morph tag.
      em.str(2, "$m: $.$m,") // bling: $m: morph value.
    }
    em.append("});")
  }
}
