// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Alias: _Form, Stmt, Def { // type alias: `TypeName := TypeExpr`.
  let sym: Sym
  let type: TypeExpr

  init(_ syn: Syn, sym: Sym, type: TypeExpr) {
    self.sym = sym
    self.type = type
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Alias(Syn(l.syn, r.syn),
      sym: castForm(l, "alias", "name symbol"),
      type: castForm(r, "alias", "type expression"))
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    type.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
  }
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    return .Type(type.typeVal(scope, "type alias"))
  }
}

