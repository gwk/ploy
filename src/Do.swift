// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: _Form, Expr { // do block: `{…}`.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, exprs.isEmpty ? " {}\n" : "\n")
    for e in exprs {
      e.writeTo(&target, depth + 1)
    }
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    for (i, expr) in exprs.enumerate() {
      if i == exprs.count - 1 { break }
      let stmtType = expr.typeForExpr(ctx, scope)
      ctx.constrain(expr, stmtType, to: self, typeVoid, "statement")
    }
    let type: Type
    if let last = exprs.last {
      type = last.typeForExpr(ctx, LocalScope(parent: scope))
    } else {
      type = typeVoid
    }
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "(function(){")
    compileBody(ctx, em, depth + 1, isTail: isTail)
    em.append("})()")
  }

  // MARK: Body
  
  func compileBody(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    for (i, expr) in exprs.enumerate() {
      let isLast = (i == exprs.lastIndex)
      if isLast {
        em.str(depth, "return (")
      }
      expr.compileExpr(ctx, em, depth, isTail: isLast && isTail)
      em.append(isLast ? ")" : ";")
    }
  }
}

