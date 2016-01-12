// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Call : _Form, Expr, Stmt {
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
  
  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    let em = scope.em
    em.str(depth, isTail ? "{" : "_tramp({")
    em.str(depth, " c:")
    let fnType = callee.compileExpr(ctx, depth + 1, scope, ctx.addFreeTypeSig(ret: expType), isTail: false)
    em.append(",")
    em.str(depth, " v:")
    arg.compileExpr(ctx, depth + 1, scope, fnType.sigPar, isTail: false)
    em.append(isTail ? "}" : "})")
    return fnType.sigRet
  }
  
  func compileStmt(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope) {
    compileExpr(ctx, depth, scope, ctx.addFreeType(), isTail: false)
  }
}


// function call implied by adjacency to Cmpd: `f(a b)`.
class CallAdj: Call {}
