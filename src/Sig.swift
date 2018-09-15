// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: ActFormBase, ActForm { // function signature: `Domain%Return`.
  let dom: Expr
  let ret: Expr

  required init(_ syn: Syn, dom: Expr, ret: Expr) {
    self.dom = dom
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      dom: Expr.expect(l, subj: "signature domain"),
      ret: Expr.expect(r, subj: "signature return"))
  }

  static var expDesc: String { return "`%` signature" }

  var textTreeChildren: [Any] { return [dom, ret] }
}

