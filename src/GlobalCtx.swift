// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalCtx {
  let mainPath: String
  let file: OutFile
  var conversions: Set<Conversion> = []

  init(mainPath: String, file: OutFile) {
    self.mainPath = mainPath
    self.file = file
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
      let em = Emitter(file: file)
      switch (orig.kind, cast.kind) {
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
    em.append("})")
  }
}
