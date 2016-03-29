// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Arg: _Form { // compound argument.
  
  let expr: Expr
  let label: Sym?
  
  init(_ syn: Syn, expr: Expr, label: Sym?) {
    self.expr = expr
    self.label = label
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    expr.writeTo(&target, depth + 1)
  }

  func typeParForArg(ctx: TypeCtx, _ scope: LocalScope, index: Int) -> TypePar {
    return TypePar(index: index, label: label, type: expr.typeForExpr(ctx, scope))
  }

  func compileArg(ctx: TypeCtx, _ em: Emitter, _ depth: Int) {
    return expr.compileExpr(ctx, em, depth, isTail: false)
  }
  
  static func mk(form: Form, _ subj: String) -> Arg {
    if let expr = form as? Expr {
      return Arg(expr.syn, expr: expr, label: nil)
    } else if let bind = form as? Bind {
      return Arg(bind.syn, expr: bind.val, label: bind.sym)
    } else {
      form.failSyntax("\(subj) argument currently limited to require an expression.")
    }
  }
}

