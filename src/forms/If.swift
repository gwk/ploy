// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: _Form, Expr { // if statement: `if cases… default;`.
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
    // TODO: much more to do here when default is missing;
    // e.g. inferring complete case coverage without default, typeHalt support, etc.
    for c in cases {
      let cond = c.condition
      let cons = c.consequence
      ctx.constrain(cond, cond.typeForExpr(ctx, scope), to: c, typeBool)
      ctx.constrain(cons, cons.typeForExpr(ctx, scope), to: self, type)
    }
    if let dflt = dflt {
      ctx.constrain(dflt, dflt.typeForExpr(ctx, scope), to: self, type)
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
}

