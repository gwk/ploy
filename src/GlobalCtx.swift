// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalCtx {
  let mainPath: String
  let file: OutFile
  var conversions: [String:Type] = [:]

  init(mainPath: String, file: OutFile) {
    self.mainPath = mainPath
    self.file = file
  }

  func addConversion(_ castName: String, _ type: Type) {
    if !conversions.contains(key: castName) {
      conversions[castName] = type
    }
  }

  func emitConversions() {
    for (name, type) in conversions.sorted(by: {$0.0 < $1.0}) {
      emitConversion(name, type)
    }
  }

  func emitConversion(_ name: String, _ type: Type) {
    guard case .conv(let orig, let cast) = type.kind else { fatalError() }
    let em = Emitter(file: file)
    em.str(0, "function \(name)($) { // \(type)")

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
