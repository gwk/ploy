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
    conversions.insert(type)
  }

  func emitConversions() {
    for type in conversions.sorted(by: {$0.globalIndex < $1.globalIndex}) {
      emitConversion(type: type)
    }
  }

  func emitConversion(type: Type) {
    guard case .conv(let orig, let cast) = type.kind else { fatalError() }
    let em = Emitter(file: file)
    em.str(0, "function \(type.convFnName)($) { // \(type)")

    switch (orig.kind, cast.kind) {

    case (.cmpd(let origFields), .cmpd(let castFields)):
      em.str(1, "return {")
      for (i, (o, c)) in zip(origFields, castFields).enumerated() {
        em.str(2, "\(c.hostName(index: i)): $.\(o.hostName(index: i)),")
      }
      em.append("};")

    default: fatalError("impossible conversion: \(type)")
    }
    em.append("}")
    em.flush()
  }
}
