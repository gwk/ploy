// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: Form { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Default?

  init(_ syn: Syn, cases: [Case], dflt: Default?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override var textTreeChildren: [Any] {
    var children: [Any] = cases
    children.appendOpt(dflt)
    return children
  }
}
