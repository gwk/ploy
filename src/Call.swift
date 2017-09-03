// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Call: Form {
  let callee: Expr
  let arg: Expr

  required init(_ syn: Syn, callee: Expr, arg: Expr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      callee: Expr(form: l, subj: "call"),
      arg: Expr(form: r, subj: "call"))
  }

  override var textTreeChildren: [Any] { return [callee, arg] }
}


// function call implied by adjacency to parenthesized: `f(a b)`.
class CallAdj: Call {}
