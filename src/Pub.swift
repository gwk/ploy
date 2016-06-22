// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Pub: _Form, Def { // public modifier: `pub expr;`.
  let def: Def

  init(_ syn: Syn, def: Def) {
    self.def = def
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    def.write(to: &stream, depth + 1)
  }

  // MARK: Def

  var sym: Sym { return def.sym }

  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    fatalError()
  }
}

