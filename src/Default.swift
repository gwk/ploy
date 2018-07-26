// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


class Default: ActFormBase, ActForm { // default clause: `/ X`.
  let expr: Expr

  init(_ syn: Syn, expr: Expr) {
    self.expr = expr
    super.init(syn)
  }

  static var expDesc: String { return "`/` default clause" }

  var textTreeChildren: [Any] { return [expr] }
}
