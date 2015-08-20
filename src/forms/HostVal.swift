// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: _Form, Def { // host value declaration: `host-val sym Type;`.
  let sym: Sym
  let type: TypeExpr

  init(_ syn: Syn, sym: Sym, type: TypeExpr) {
    self.sym = sym
    self.type = type
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    type.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    scope.addRec(sym, isFwd: false, kind: .Val(type.typeVal(scope, "host value declaration"))) // host declarations are never lazy.
    return typeVoid
  }
  
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    return .Val(type.typeVal(scope, "host value type"))
  }
}
