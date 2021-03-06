// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: ActFormBase, ActForm { // do block: `{…}`.
  let body: Body

  init(_ syn: Syn, body: Body) {
    self.body = body
    super.init(syn)
  }

  convenience init(_ syn: Syn, stmts: [Expr], expr: Expr) {
    self.init(syn, body: Body(syn, stmts: stmts, expr: expr))
  }

  static var expDesc: String { return "`{…}` do form" }

  var textTreeChildren: [Any] { return [body] }
}
