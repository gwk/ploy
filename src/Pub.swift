// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Pub: Form { // public modifier: `pub expr;`.
  let def: Def

  init(_ syn: Syn, def: Def) {
    self.def = def
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    def.form.write(to: &stream, depth + 1)
  }
}

