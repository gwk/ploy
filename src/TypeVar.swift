// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVar: ActFormBase, ActForm { // type var: `T::Requirement`.
  let sym: Sym
  let requirement: Expr

  required init(_ syn: Syn, sym: Sym, requirement: Expr) {
    self.sym = sym
    self.requirement = requirement
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      sym: Sym.expect(l, subj: "type var"),
      requirement: Expr.expect(r, subj: "type var"))
  }

  static var expDesc: String { return "`::` type var" }

  var textTreeChildren: [Any] { return [sym, requirement] }
}
