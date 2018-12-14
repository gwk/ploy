// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Where: ActFormBase, ActForm { // where: `T:?pred`.
  let base: Expr
  let pred: Expr

  required init(_ syn: Syn, base: Expr, pred: Expr) {
    self.base = base
    self.pred = pred
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      base: Expr.expect(l, subj: "where operator", exp: "base"),
      pred: Expr.expect(r, subj: "where operator", exp: "predicate"))
  }

  static var expDesc: String { return "`:?` where operator" }

  var textTreeChildren: [Any] { return [base, pred] }
}
