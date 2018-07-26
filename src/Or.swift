// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Or: ActFormBase, ActForm { // or form: `or …;`.
  let terms: [Expr]

  init(_ syn: Syn, terms: [Expr]) {
    self.terms = terms
    super.init(syn)
  }

  static var expDesc: String { return "`or`" }

  var textTreeChildren: [Any] { return terms }
}
