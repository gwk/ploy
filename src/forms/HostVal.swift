// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: _Form, Def { // host value declaration: `host-val sym Type;`.
  let sym: Sym
  let typeExpr: TypeExpr

  init(_ syn: Syn, sym: Sym, typeExpr: TypeExpr) {
    self.sym = sym
    self.typeExpr = typeExpr
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    typeExpr.writeTo(&target, depth + 1)
  }
  
  func compileDef(em: Emit, _ scope: Scope) {
    scope.addRecord(sym, isFwd: false, kind: .Val(typeExpr.typeVal(scope, "host value declaration")))
  }
  
  func scopeRecordKind(scope: Scope) -> ScopeRecord.Kind {
    return .Val(typeExpr.typeVal(scope, "host value type"))
  }
}
