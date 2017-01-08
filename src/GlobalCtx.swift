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
    for conv in conversions.sorted() {
      let orig = conv.orig
      let cast = conv.cast
      let em = Emitter(file: file)
      switch (orig.kind, cast.kind) {
      case (.cmpd(let origFields), .cmpd(let castFields)):
        emitCmpdCmpd(em, conv: conv, origFields: origFields, castFields: castFields)
      default: fatalError("impossible conversion: \(conv)")
      }
      em.flush()
    }
  }

  func emitCmpdCmpd(_ em: Emitter, conv: Conversion, origFields: [TypeField], castFields: [TypeField]) {
    em.str(0, "let \(conv.hostName) = $=>({ // \(conv)")
    for (i, (o, c)) in zip(origFields, castFields).enumerated() {
      let cName = c.hostName(index: i)
      let oName = o.hostName(index: i)
      em.str(2, "\(cName): $.\(oName),")
    }
    em.append("})")
  }
}
