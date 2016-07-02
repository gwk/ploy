// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: Form { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Expr?

  init(_ syn: Syn, cases: [Case], dflt: Expr?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    for c in cases {
      c.write(to: &stream, depth + 1)
    }
    if let dflt = dflt {
      dflt.form.write(to: &stream, depth + 1)
    }
  }
}

