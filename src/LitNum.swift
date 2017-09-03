// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: Form { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    self.val = val
    super.init(syn)
  }

  override var description: String {
    return "\(type(of: self)):\(syn): \(val)"
  }

  override var textTreeChildren: [Any] { return [] }

  var cloned: LitNum {
    return LitNum(syn, val: val)
  }
}
