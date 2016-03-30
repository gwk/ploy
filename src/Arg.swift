// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Arg: _Form { // compound argument.
  
  let label: Sym?
  let expr: Expr
  
  init(_ syn: Syn, label: Sym?, expr: Expr) {
    self.label = label
    self.expr = expr
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    if let label = label {
      label.writeTo(&target, depth + 1)
    }
    expr.writeTo(&target, depth + 1)
  }

  func typeParForArg(ctx: TypeCtx, _ scope: LocalScope, index: Int) -> TypePar {
    return TypePar(index: index, label: label, type: expr.typeForExpr(ctx, scope))
  }

  func compileArg(ctx: TypeCtx, _ em: Emitter, _ depth: Int) {
    return expr.compileExpr(ctx, em, depth, isTail: false)
  }
  
  static func mk(form: Form, _ subj: String) -> Arg {
    if let bind = form as? Bind {
      return Arg(bind.syn, label: bind.sym, expr: bind.val)
    } else if let expr = form as? Expr {
      return Arg(expr.syn, label: nil, expr: expr)
    } else {
      form.failSyntax("\(subj) argument currently limited to require an expression.")
    }
  }
}

