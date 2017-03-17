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

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    expr.write(to: &stream, depth + 1)
    for c in cases {
      c.write(to: &stream, depth + 1)
    }
    if let dflt = dflt {
      dflt.write(to: &stream, depth + 1)
    }
  }
}

