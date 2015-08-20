// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostType: _Form, Def { // host type declaration: `host-type sym;`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    scope.addRec(sym, isFwd: false, kind: .Type(TypeValDecl(sym: sym)))
    return typeVoid
  }
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    return .Type(TypeValDecl(sym: sym))
  }
}
