// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Where: ActFormBase, ActForm { // where: `x::p`.
  let left: Expr
  let right: Expr

  required init(_ syn: Syn, left: Expr, right: Expr) {
    self.left = left
    self.right = right
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      left: Expr.expect(l, subj: "where operator"),
      right: Expr.expect(r, subj: "where operator"))
  }

  static var expDesc: String { return "`::` where clause" }

  var textTreeChildren: [Any] { return [left, right] }
}
