// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Intersection: ActFormBase, ActForm { // intersection: `A & B`.
  let left: Expr
  let right: Expr

  required init(_ syn: Syn, left: Expr, right: Expr) {
    self.left = left
    self.right = right
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      left: Expr.expect(l, subj: "intersection"),
      right: Expr.expect(r, subj: "intersection"))
  }

  static var expDesc: String { return "`&` type intersection" }

  var textTreeChildren: [Any] { return [left, right] }
}
