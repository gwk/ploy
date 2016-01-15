// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: _Form, Expr { // do block: `{…}`.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for e in exprs {
      e.writeTo(&target, depth + 1)
    }
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    if let last = exprs.last {
      return last.typeForExpr(ctx, LocalScope(parent: scope, em: scope.em))
    } else {
      return typeVoid
    }
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, "(function(){")
    compileBody(ctx, LocalScope(parent: scope, em: em), depth + 1, isTail: isTail)
    em.append("})()")
  }

  // MARK: Body
  
  func compileBody(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    for (i, expr) in exprs.enumerate() {
      let isLast = (i == exprs.lastIndex)
      if isLast {
        em.str(depth, "return (")
      }
      expr.compileExpr(ctx, scope, depth, isTail: isLast && isTail)
      em.append(isLast ? ")" : ";")
    }
  }
}

