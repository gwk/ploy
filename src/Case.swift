// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Case: ActFormBase, ActForm { // conditional case: `condition ? consequence`.
  let condition: Expr
  let consequence: Expr

  init (_ syn: Syn, condition: Expr, consequence: Expr) {
    self.condition = condition
    self.consequence = consequence
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return Case(Syn(l.syn, r.syn),
      condition: Expr.expect(l, subj: "case", exp: "condition"),
      consequence: Expr.expect(r, subj: "case", exp: "consequence"))
  }

  static var expDesc: String { return "`?` case" }

  var textTreeChildren: [Any] { return [condition, consequence] }
}
