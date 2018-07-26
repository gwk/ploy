// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: ActFormBase, ActForm { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }

  override var description: String {
    return "\(type(of: self)):\(syn): '\(val)'" // TODO: use actual source string?
  }

  static var expDesc: String { return "string literal" }

  var textTreeChildren: [Any] { return [] }
}


