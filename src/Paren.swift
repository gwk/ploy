// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Paren: _Form, Expr { // parenthesized expression: `(a)`.
  let expr: Expr
  
  init(_ syn: Syn, expr: Expr) {
    self.expr = expr
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    expr.writeTo(&target, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = expr.typeForExpr(ctx, scope)
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "(")
    expr.compileExpr(ctx, em, depth + 1, isTail: isTail)
    em.append(")")
  }
}

