// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Intersect: ActFormBase, ActForm { // intersect: `A & B`.
  let left: Expr
  let right: Expr

  init(_ syn: Syn, left: Expr, right: Expr) {
    self.left = left
    self.right = right
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return Union(Syn(l.syn, r.syn),
      left: Expr.expect(l, subj: "intersect"),
      right: Expr.expect(r, subj: "intersect"))
  }

  static var expDesc: String { return "`&` type intersection" }

  var textTreeChildren: [Any] { return [left, right] }
}
