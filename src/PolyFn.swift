// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class PolyFn: Form {
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
  }
}
