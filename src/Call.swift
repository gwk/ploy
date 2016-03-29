// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Call : _Form, Expr {
  let callee: Expr
  let arg: Expr
  
  required init(_ syn: Syn, callee: Expr, arg: Expr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      callee: castForm(l, "call", "expression"),
      arg: castForm(r, "call", "expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    callee.writeTo(&target, depth + 1)
    arg.writeTo(&target, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let calleeType = callee.typeForExpr(ctx, scope)
    let argType = arg.typeForExpr(ctx, scope)
    let type = ctx.addFreeType()
    ctx.trackExpr(self, type: type)
    ctx.constrain(callee, calleeType, to: self, Type.Sig(par: argType, ret: type), "call type")
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, isTail ? "{" : "_tramp({")
    em.str(depth, " c:")
    callee.compileExpr(ctx, em, depth + 1, isTail: false)
    em.append(",")
    em.str(depth, " v:")
    arg.compileExpr(ctx, em, depth + 1, isTail: false)
    em.append(isTail ? "}" : "})")
  }
}


// function call implied by adjacency to Cmpd: `f(a b)`.
class CallAdj: Call {}
