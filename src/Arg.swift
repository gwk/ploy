// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Arg: Form { // compound argument.
  
  let label: Sym?
  let expr: Expr
  
  init(_ syn: Syn, label: Sym?, expr: Expr) {
    self.label = label
    self.expr = expr
    super.init(syn)
  }
  
  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    if let label = label {
      label.write(to: &stream, depth + 1)
    }
    expr.write(to: &stream, depth + 1)
  }

  func typeParForArg(_ ctx: TypeCtx, _ scope: LocalScope, index: Int) -> TypePar {
    return TypePar(index: index, label: label, type: expr.genTypeConstraints(ctx, scope))
  }

  func compileArg(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int) {
    return expr.compile(ctx, em, depth, isTail: false)
  }
  
  static func mk(_ form: Form, _ subj: String) -> Arg {
    if let bind = form as? Bind {
      return Arg(bind.syn, label: bind.sym, expr: bind.val)
    }
    let expr = Expr(form: form, subj: subj, exp: "expression (temporary limitation)")
    return Arg(expr.syn, label: nil, expr: expr)
  }
}

