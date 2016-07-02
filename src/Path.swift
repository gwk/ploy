// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class Path: _Form { // path: `LIB/name`.
  let syms: [Sym]
  
  init(_ syn: Syn, syms: [Sym]) {
    check(syms.count > 0)
    self.syms = syms
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": ")
    var first = true
    for s in syms {
      if first {
        first = false
      } else {
        stream.write("/")
      }
      stream.write(s.name)
    }
    stream.write("\n")
  }
}

