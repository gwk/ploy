// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Arg: _Form { // parameter.
  
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
  
  func compileArg(em: Emitter, _ depth: Int, _ scope: Scope, _ expType: Type) -> Type {
    return expr.compileExpr(em, depth, scope, expType, isTail: false)
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

