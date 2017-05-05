// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeAlias: Form { // type binding: `Alias =: Type`.

  let sym: Sym
  let expr: Expr

  init(_ syn: Syn, sym: Sym, expr: Expr) {
    self.sym = sym
    self.expr = expr
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    guard let sym = l as? Sym else {
      l.failSyntax("type alias expects symbol but received \(l.syntaxName).")
    }
    return TypeAlias(Syn(l.syn, r.syn),
      sym: sym,
      expr: Expr(form: r, subj: "type alias", exp: "type expression"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    sym.write(to: &stream, depth + 1)
    expr.write(to: &stream, depth + 1)
  }
}
