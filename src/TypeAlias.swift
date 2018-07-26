// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeAlias: ActFormBase, ActForm { // type binding: `Alias =: Type`.
  let sym: Sym
  let expr: Expr

  init(_ syn: Syn, sym: Sym, expr: Expr) {
    self.sym = sym
    self.expr = expr
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return TypeAlias(Syn(l.syn, r.syn),
      sym: Sym.expect(l, subj: "type alias"),
      expr: Expr.expect(r, subj: "type alias", exp: "type expression"))
  }

  static var expDesc: String { return "`=:` type alias" }

  var textTreeChildren: [Any] { return [sym, expr] }
}
