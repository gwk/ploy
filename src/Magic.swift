// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Magic: ActFormBase, ActForm { // synthesized code.
  let type: Type
  let code: String

  init(_ syn: Syn, type: Type, code: String) {
    self.type = type
    self.code = code
    super.init(syn)
  }

  override var description: String {
    return "\(typeDescription(self)):\(syn): \(type); \(code)"
  }

  static var expDesc: String { return "magic form" }

  var textTreeChildren: [Any] { return [] }
}
