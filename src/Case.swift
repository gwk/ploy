// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Case: Form { // conditional case: `condition ? consequence`.
  let condition: Expr
  let consequence: Expr

  init (_ syn: Syn, condition: Expr, consequence: Expr) {
    self.condition = condition
    self.consequence = consequence
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Case(Syn(l.syn, r.syn),
      condition: Expr(form: l, subj: "case", exp: "condition"),
      consequence: Expr(form: r, subj: "case", exp: "consequence"))
  }

  override var textTreeChildren: [Any] { return [condition, consequence] }
}
