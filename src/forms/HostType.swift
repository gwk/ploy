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
  
  func compileDef(em: Emit, _ scope: Scope) {
    scope.addRec(sym, isFwd: false, kind: .Type(TypeDecl(sym: sym)))
  }
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    return .Type(TypeDecl(sym: sym))
  }
}
