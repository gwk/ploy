// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalCtx {
  let mainPath: String
  let file: OutFile
  var conversions: Set<Type> = []

  init(mainPath: String, file: OutFile) {
    self.mainPath = mainPath
    self.file = file
  }

  func addConversion(_ type: Type) {
    let hasConv = type.addTypesContainingConvs(set: &conversions)
    assert(hasConv)
  }

  func emitConversions() {
    for type in conversions.sorted(by: {$0.globalIndex < $1.globalIndex}) {
      let em = Emitter(file: file)
      em.str(0, "let \(type.hostConvName) = $=>({ // \(type)")
      switch type.kind {
      case .conv(let orig, let cast): emitConv(em, type: type, orig: orig, cast: cast)
      case .cmpd(let fields): emitCmpdConv(em, fields: fields)
      default: fatalError()
      }
      em.append("})")
      em.flush()
    }
  }

  func emitConv(_ em: Emitter, type: Type, orig: Type, cast: Type) {
    switch (orig.kind, cast.kind) {
    case (.cmpd(let origFields), .cmpd(let castFields)):
      for (i, (o, c)) in zip(origFields, castFields).enumerated() {
        assert(!o.type.hasConv)
        assert(!c.type.hasConv)
        let cName = c.hostName(index: i)
        let oName = o.hostName(index: i)
        em.str(2, "\(cName): $.\(oName),")
      }
    default: fatalError("impossible conversion: \(type)")
    }
  }

  func emitCmpdConv(_ em: Emitter, fields: [TypeField]) {
    for (i, field) in fields.enumerated() {
      let name = field.hostName(index: i)
      if field.type.hasConv {
        assert(conversions.contains(field.type))
        em.str(2, "\(name): \(field.type.hostConvName)($.\(name)),")
      } else {
        em.str(2, "\(name): $.\(name),")
      }
    }
  }
}
