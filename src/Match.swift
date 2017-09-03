// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Match: Form { // match statement: `match cond0 ? then0 … / default;`.
  let expr: Expr
  let cases: [Case]
  let dflt: Default?

  init(_ syn: Syn, expr: Expr, cases: [Case], dflt: Default?) {
    self.expr = expr
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override var textTreeChildren: [Any] {
    var children: [Any] = [expr]
    children.append(contentsOf: cases.map {$0})
    children.appendOpt(dflt)
    return children
  }
}

