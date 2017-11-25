// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Intersect: Form { // intersect: `A & B`.
  let left: Expr
  let right: Expr

  init(_ syn: Syn, left: Expr, right: Expr) {
    self.left = left
    self.right = right
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Union(Syn(l.syn, r.syn),
      left: Expr(form: l, subj: "intersect"),
      right: Expr(form: r, subj: "intersect"))
  }

  override var textTreeChildren: [Any] { return [left, right] }
}
