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
    let retType = ctx.addFreeType()
    ctx.constrain(callee, calleeType, to: self, Type.Sig(par: argType, ret: retType))
    return retType
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, isTail ? "{" : "_tramp({")
    em.str(depth, " c:")
    callee.compileExpr(ctx, scope, depth + 1, isTail: false)
    em.append(",")
    em.str(depth, " v:")
    arg.compileExpr(ctx, scope, depth + 1, isTail: false)
    em.append(isTail ? "}" : "})")
  }
}


// function call implied by adjacency to Cmpd: `f(a b)`.
class CallAdj: Call {}
