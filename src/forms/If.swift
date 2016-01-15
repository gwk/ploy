// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: _Form, Expr, Stmt { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Expr?

  init(_ syn: Syn, cases: [Case], dflt: Expr?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for c in cases {
      c.writeTo(&target, depth + 1)
    }
    if let dflt = dflt {
      dflt.writeTo(&target, depth + 1)
    }
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = (dflt == nil) ? typeVoid: ctx.addFreeType() // all cases must return same type.
    for c in cases {
      ctx.addConstraint(typeBool, c.condition.typeForExpr(ctx, scope))
      ctx.addConstraint(type, c.consequence.typeForExpr(ctx, scope))
    }
    if let dflt = dflt {
      ctx.addConstraint(type, dflt.typeForExpr(ctx, scope))
    }
    return type
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, "(")
    for c in cases {
      c.condition.compileExpr(ctx, scope, depth + 1, isTail: false)
      em.append(" ?")
      c.consequence.compileExpr(ctx, scope, depth + 1, isTail: isTail)
      em.append(" :")
    }
    if let dflt = dflt {
      dflt.compileExpr(ctx, scope, depth + 1, isTail: isTail)
    } else {
      em.str(depth + 1, "undefined")
    }
    em.append(")")
  }

  // MARK: Stmt

  func typecheckStmt(ctx: TypeCtx, _ scope: LocalScope) {
    typeForExpr(ctx, scope)
  }

  func compileStmt(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int) {
    compileExpr(ctx, scope, depth, isTail: false)
  }
}

