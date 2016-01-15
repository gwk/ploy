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
    return expr.typeForExpr(ctx, scope)
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, "(")
    expr.compileExpr(ctx, scope, depth + 1, isTail: isTail)
    em.append(")")
  }
}

