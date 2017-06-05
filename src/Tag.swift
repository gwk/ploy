// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Tag: Form { // tag: `-X`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    sym.write(to: &stream, depth + 1)
  }

  // Tag.

  var cloned: Tag { return Tag(syn, sym: sym.cloned) }
}

