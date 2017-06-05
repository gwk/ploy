// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class And: Form { // and form: `and …;`.
  let terms: [Expr]

  init(_ syn: Syn, terms: [Expr]) {
    self.terms = terms
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    for term in terms {
      term.write(to: &stream, depth + 1)
    }
  }
}
