// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Call: ActFormBase, ActForm {
  let callee: Expr
  let arg: Expr

  init(_ syn: Syn, callee: Expr, arg: Expr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      callee: Expr.expect(l, subj: "call"),
      arg: Expr.expect(r, subj: "call"))
  }

  static var expDesc: String { return "call" }

  var textTreeChildren: [Any] { return [callee, arg] }
}


// function call implied by adjacency to parenthesized: `f(a b)`.
class CallAdj: Call {}
