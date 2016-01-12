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
  
  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    let em = scope.em
    em.str(depth, "(")
    let retType = expr.compileExpr(ctx, depth + 1, scope, expType, isTail: isTail)
    em.append(")")
    return retType
  }
}

