// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: _Form, Expr { // annotation: `val:Type`.
  let val: Expr
  let type: TypeExpr
  
  init(_ syn: Syn, val: Expr, type: TypeExpr) {
    self.val = val
    self.type = type
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Ann(Syn(l.syn, r.syn),
      val: castForm(l, "type annotation", "expression"),
      type: castForm(r, "type annotation", "type expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    val.writeTo(&target, depth + 1)
    type.writeTo(&target, depth + 1)
  }
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    let typeVal = type.typeVal(scope, "annotation")
    if !expType.accepts(typeVal) {
      failType("expected type: \(expType); actual type: \(typeVal)")
    }
    return val.compileExpr(em, depth, scope, typeVal, isTail: isTail)
  }
}


