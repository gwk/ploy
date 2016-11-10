// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: Form { // host value declaration: `host_val sym Type;`.
  let sym: Sym
  let typeExpr: TypeExpr
  let code: LitStr

  init(_ syn: Syn, sym: Sym, typeExpr: TypeExpr, code: LitStr) {
    self.sym = sym
    self.typeExpr = typeExpr
    self.code = code
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    typeExpr.write(to: &stream, depth + 1)
    code.write(to: &stream, depth + 1)
  }
}
