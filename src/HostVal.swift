// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: _Form, Def { // host value declaration: `host-val sym Type;`.
  let sym: Sym
  let typeExpr: TypeExpr

  init(_ syn: Syn, sym: Sym, typeExpr: TypeExpr) {
    self.sym = sym
    self.typeExpr = typeExpr
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    typeExpr.write(to: &stream, depth + 1)
  }

  // MARK: Def

  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    let type = typeExpr.typeForTypeExpr(space, "host value declaration")
    return .val(type)
  }
}
