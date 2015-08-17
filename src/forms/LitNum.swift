// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: _Form, Expr { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    self.val = val
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(String(val))
    target.write("\n")
  }

  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    // TODO: typecheck.
    em.str(depth, val.dec)
    return typeInt
  }
}

