// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostType: _Form, Def { // host type declaration: `host-type sym;`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
  }

  // MARK: Def

  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    return .type(Type.Host(spacePathNames: space.pathNames, sym: sym))
  }
}
