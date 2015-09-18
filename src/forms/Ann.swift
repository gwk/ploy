// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: _Form, Expr { // annotation: `val:Type`.
  let val: Expr
  let typeExpr: TypeExpr
  
  init(_ syn: Syn, val: Expr, typeExpr: TypeExpr) {
    self.val = val
    self.typeExpr = typeExpr
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Ann(Syn(l.syn, r.syn),
      val: castForm(l, "type annotation", "expression"),
      typeExpr: castForm(r, "type annotation", "type expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    val.writeTo(&target, depth + 1)
    typeExpr.writeTo(&target, depth + 1)
  }
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: Type, isTail: Bool) -> Type {
    let type = typeExpr.typeVal(scope, "annotation")
    if !expType.accepts(type) {
      failType("expected type: \(expType); actual type: \(type)")
    }
    return val.compileExpr(em, depth, scope, type, isTail: isTail)
  }
}


