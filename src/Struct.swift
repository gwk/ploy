// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Struct: _Form { // struct declaration: `struct S fields…;`.
  let sym: Sym
  let fields: [Par]
  
  init(_ syn: Syn, sym: Sym, fields: [Par]) {
    self.sym = sym
    self.fields = fields
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    for f in fields {
      f.write(to: &stream, depth + 1)
    }
  }
}

