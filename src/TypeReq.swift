// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeReq: ActFormBase, ActForm { // type requirement: `Base::Requirement`.
  let base: Expr
  let requirement: Expr

  required init(_ syn: Syn, base: Expr, requirement: Expr) {
    self.base = base
    self.requirement = requirement
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      base: Expr.expect(l, subj: "type requiree"),
      requirement: Expr.expect(r, subj: "type requirement"))
  }

  static var expDesc: String { return "`::` type requirement" }

  var textTreeChildren: [Any] { return [base, requirement] }
}
