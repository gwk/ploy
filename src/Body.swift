// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Body: Form { // body of statements and final expression.
  let stmts: [Expr]
  let expr: Expr

  init(_ syn: Syn, exprs: [Expr]) {
    if let expr = exprs.last {
      self.stmts = Array(exprs[0..<exprs.lastIndex!])
      self.expr = expr
    } else {
      self.stmts = []
      self.expr = .void(ImplicitVoid(syn))
    }
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    for s in stmts {
      s.write(to: &stream, depth + 1)
    }
    expr.write(to: &stream, depth + 1)
  }
}
