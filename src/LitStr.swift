// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: Form { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }

  override var description: String {
    return "\(type(of: self)):\(syn): '\(val)'" // TODO: use actual source string?
  }

  override var textTreeChildren: [Any] { return [] }
}


