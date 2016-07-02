// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Enum: _Form { // enum declaration: `enum E variants…;`.
  let sym: Sym
  let variants: [Par]

  init(_ syn: Syn, sym: Sym, variants: [Par]) {
    self.sym = sym
    self.variants = variants
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    for v in variants {
      v.write(to: &stream, depth + 1)
    }
  }
}


