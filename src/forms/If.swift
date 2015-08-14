// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: _Form, Expr { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Expr?
  init(_ syn: Syn, cases: [Case], dflt: Expr?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for c in cases {
      c.writeTo(&target, depth + 1)
    }
    if let dflt = dflt {
      dflt.writeTo(&target, depth + 1)
    }
  }
  
}

