// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Match: ActFormBase, ActForm { // match statement: `match cond0 ? then0 … / default;`.
  let expr: Expr
  let cases: [Case]
  let dflt: Default?

  init(_ syn: Syn, expr: Expr, cases: [Case], dflt: Default?) {
    self.expr = expr
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  static var expDesc: String { return "`match`" }

  var textTreeChildren: [Any] {
    var children: [Any] = [expr]
    children.append(contentsOf: cases.map {$0})
    children.appendOpt(dflt)
    return children
  }
}
