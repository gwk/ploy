// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeArgs: Form { // type constraint: `<A B>`.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return exprs }
}
