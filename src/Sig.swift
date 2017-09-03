// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: Form { // function signature: `Domain->Return`.
  let dom: Expr
  let ret: Expr

  init(_ syn: Syn, dom: Expr, ret: Expr) {
    self.dom = dom
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Sig(Syn(l.syn, r.syn),
      dom: Expr(form: l, subj: "signature domain"),
      ret: Expr(form: r, subj: "signature return"))
  }

  override var textTreeChildren: [Any] { return [dom, ret] }
}

