// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


class HostDecl: _Form, Def { // host declaration: `PLOY-HOST name Type;`.
  let name: Sym
  let type: TypeExpr
  init(_ syn: Syn, name: Sym, type: TypeExpr) {
    self.name = name
    self.type = type
    super.init(syn)
  }
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
    type.writeTo(&target, depth + 1)
  }
}

