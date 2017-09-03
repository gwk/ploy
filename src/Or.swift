// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Or: Form { // or form: `or …;`.
  let terms: [Expr]

  init(_ syn: Syn, terms: [Expr]) {
    self.terms = terms
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return terms }
}
