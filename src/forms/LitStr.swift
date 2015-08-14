// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: _Form, Expr { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(" \"")
    target.write(val) // TODO: escape properly.
    target.write("\"\n")
  }
}

