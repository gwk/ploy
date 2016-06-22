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
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    callee.write(to: &stream, depth + 1)
    arg.write(to: &stream, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let _ = callee.typeForExpr(ctx, scope)
    let _ = arg.typeForExpr(ctx, scope)
    let parType = ctx.addFreeType()
    let type = ctx.addFreeType()
    let sigType = Type.Sig(par: parType, ret: type)
    ctx.trackExpr(self, type: type)
    ctx.constrain(callee, expForm: self, expType: sigType, "callee")
    ctx.constrain(arg, expForm: self, expType: parType, "argument")
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
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
