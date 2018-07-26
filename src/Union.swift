// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Union: ActFormBase, ActForm { // union: `A | B`.
  let left: Expr
  let right: Expr

  init(_ syn: Syn, left: Expr, right: Expr) {
    self.left = left
    self.right = right
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return Union(Syn(l.syn, r.syn),
      left: Expr.expect(l, subj: "union"),
      right: Expr.expect(r, subj: "union"))
  }

  static var expDesc: String { return "`|` type union" }

  var textTreeChildren: [Any] { return [left, right] }
}
