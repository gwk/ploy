// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeArgs: ActFormBase, ActForm { // type constraint: `<A B>`.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }

  static var expDesc: String { return "<…> type constraint" }

  var textTreeChildren: [Any] { return exprs }
}
