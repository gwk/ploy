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
      case (.struct_(let origFields), .struct_(let castFields)):
        emitStructToStruct(em, convs: &convs, conv: conv, origFields: origFields, castFields: castFields)
      default: fatalError("impossible conversion: \(conv)")
      }
      em.flush()
    }
  }

  func emitStructToStruct(_ em: Emitter, convs: inout [Conversion], conv: Conversion, origFields: [TypeField], castFields: [TypeField]) {
    em.str(0, "let \(conv.hostName) = $=>({ // \(conv)")
    for (i, (o, c)) in zip(origFields, castFields).enumerated() {
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
    em.append("})")
  }
}
