// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Body: Form { // body of statements and final expression.
  let stmts: [Expr]
  let expr: Expr

  init(_ syn: Syn, stmts: [Expr], expr: Expr) {
    self.stmts = stmts
    self.expr = expr
    super.init(syn)
  }

  convenience init(_ syn: Syn, exprs: [Expr]) {
    let _stmts: [Expr]
    let _expr: Expr
    if let expr = exprs.last {
      _stmts = Array(exprs[0..<exprs.lastIndex!])
      _expr = expr
    } else {
      _stmts = exprs
      _expr = .void(ImplicitVoid(syn))
    }
    self.init(syn, stmts: _stmts, expr: _expr)
  }

  override var textTreeChildren: [Any] { return stmts + [expr] }
}
