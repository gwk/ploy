// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Paren: _Form, Expr { // parenthesized expression: `(a)`.
  let expr: Expr
  
  init(_ syn: Syn, expr: Expr) {
    self.expr = expr
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    expr.write(to: &stream, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = expr.typeForExpr(ctx, scope)
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "(")
    expr.compileExpr(ctx, em, depth + 1, isTail: isTail)
    em.append(")")
  }
}

