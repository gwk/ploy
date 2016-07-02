// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: _Form { // annotation: `expr:Type`.
  let expr: Expr
  let typeExpr: TypeExpr
  
  init(_ syn: Syn, expr: Expr, typeExpr: TypeExpr) {
    self.expr = expr
    self.typeExpr = typeExpr
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Ann(Syn(l.syn, r.syn),
      expr: Expr(form: l, subj: "type annotation"),
      typeExpr: castForm(r, "type annotation", "type expression"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    expr.form.write(to: &stream, depth + 1)
    typeExpr.write(to: &stream, depth + 1)
  }
}

