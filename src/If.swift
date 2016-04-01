// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: _Form, Expr { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Expr?

  init(_ syn: Syn, cases: [Case], dflt: Expr?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
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
    ctx.trackExpr(self, type: type)
    // TODO: much more to do here when default is missing;
    // e.g. inferring complete case coverage without default, typeHalt support, etc.
    for c in cases {
      let cond = c.condition
      let cons = c.consequence
      let _ = cond.typeForExpr(ctx, scope)
      let _ = cons.typeForExpr(ctx, scope)
      ctx.constrain(cond, expForm: c, expType: typeBool, "if form condition")
      ctx.constrain(cons, expForm: self, expType: type, "if form consequence")
    }
    if let dflt = dflt {
      let _ = dflt.typeForExpr(ctx, scope)
      ctx.constrain(dflt, expForm: self, expType: type, "if form default")
    }
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "(")
    for c in cases {
      c.condition.compileExpr(ctx, em, depth + 1, isTail: false)
      em.append(" ?")
      c.consequence.compileExpr(ctx, em, depth + 1, isTail: isTail)
      em.append(" :")
    }
    if let dflt = dflt {
      dflt.compileExpr(ctx, em, depth + 1, isTail: isTail)
    } else {
      em.str(depth + 1, "undefined")
    }
    em.append(")")
  }
}

