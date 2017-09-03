// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: Form { // annotation: `expr:Type`.
  let expr: Expr
  let typeExpr: Expr

  init(_ syn: Syn, expr: Expr, typeExpr: Expr) {
    self.expr = expr
    self.typeExpr = typeExpr
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Ann(Syn(l.syn, r.syn),
      expr: Expr(form: l, subj: "type annotation"),
      typeExpr: Expr(form: r, subj: "type annotation"))
  }

  override var textTreeChildren: [Any] { return [expr, typeExpr] }
}
