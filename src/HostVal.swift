// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: _Form, Def { // host value declaration: `host-val sym Type;`.
  let sym: Sym
  let typeExpr: TypeExpr

  init(_ syn: Syn, sym: Sym, typeExpr: TypeExpr) {
    self.sym = sym
    self.typeExpr = typeExpr
    super.init(syn)
  }

  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    sym.writeTo(&target, depth + 1)
    typeExpr.writeTo(&target, depth + 1)
  }

  // MARK: Def

  func compileDef(space: Space) -> ScopeRecord.Kind {
    let type = typeExpr.typeForTypeExpr(space, "host value declaration")
    return .val(type)
  }
}
