// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostType: _Form, Def { // host type declaration: `host-type name;`.
  let name: Sym

  init(_ syn: Syn, name: Sym) {
    self.name = name
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    scope.addRec(name, .Type, TypeValPrim(name: name))
    return typeVoid
  }
}
