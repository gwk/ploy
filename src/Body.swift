// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Body: Form { // body of statements and final expression.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, exprs.isEmpty ? "(empty)\n" : "\n")
    for e in exprs {
      e.write(to: &stream, depth + 1)
    }
  }
}
