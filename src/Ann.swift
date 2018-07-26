// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Ann: ActFormBase, ActForm { // annotation: `expr:Type`.
  let expr: Expr
  let typeExpr: Expr

  init(_ syn: Syn, expr: Expr, typeExpr: Expr) {
    self.expr = expr
    self.typeExpr = typeExpr
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return Ann(Syn(l.syn, r.syn),
      expr: Expr.expect(l, subj: "type annotation"),
      typeExpr: Expr.expect(r, subj: "type annotation"))
  }

  static var expDesc: String { return "`:` type annotation" }

  var textTreeChildren: [Any] { return [expr, typeExpr] }
}
