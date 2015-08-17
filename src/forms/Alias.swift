// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Alias: _Form, Stmt, Def { // type alias: `TypeName := TypeExpr`.
  let name: Sym
  let type: TypeExpr

  init(_ syn: Syn, name: Sym, type: TypeExpr) {
    self.name = name
    self.type = type
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Alias(Syn(l.syn, r.syn),
      name: castForm(l, "alias", "name symbol"),
      type: castForm(r, "alias", "type expression"))
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
    type.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
  }
}

