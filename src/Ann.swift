// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: _Form, Expr { // annotation: `expr:Type`.
  let expr: Expr
  let typeExpr: TypeExpr
  
  init(_ syn: Syn, expr: Expr, typeExpr: TypeExpr) {
    self.expr = expr
    self.typeExpr = typeExpr
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Ann(Syn(l.syn, r.syn),
      expr: castForm(l, "type annotation", "expression"),
      typeExpr: castForm(r, "type annotation", "type expression"))
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    expr.writeTo(&target, depth + 1)
    typeExpr.writeTo(&target, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let _ = expr.typeForExpr(ctx, scope)
    let type = typeExpr.typeForTypeExpr(scope, "type annotation")
    ctx.trackExpr(self, type: type)
    ctx.constrain(expr, expForm: typeExpr, expType: type, "type annotation")
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    expr.compileExpr(ctx, em, depth, isTail: isTail)
  }
}

