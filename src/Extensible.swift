// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class Extensible: Form {
  let sym: Sym
  let constraints: [Expr]

  init(_ syn: Syn, sym: Sym, constraints: [Expr]) {
    self.sym = sym
    self.constraints = constraints
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    sym.write(to: &stream, depth + 1)
    for constraint in constraints {
      constraint.write(to: &stream, depth + 1)
    }
  }
}
