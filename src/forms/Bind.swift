// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Stmt, Def { // value binding: `name=expr`.
  let name: Sym
  let val: Expr
  
  init(_ syn: Syn, name: Sym, val: Expr) {
    self.name = name
    self.val = val
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Bind(Syn(l.syn, r.syn),
      name: castForm(l, "binding", ""),
      val: castForm(r, "binding", ""))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
    val.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
    return typeVoid
  }
}

