// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Body: Form { // body of statements and final expression.
  let stmts: [Expr]
  let expr: Expr?

  init(_ syn: Syn, exprs: [Expr]) {
    if exprs.isEmpty {
      self.stmts = []
      self.expr = nil
    } else {
      self.stmts = Array(exprs[0..<exprs.lastIndex!])
      self.expr = exprs.last
    }
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, (expr == nil) ? "(empty)\n" : "\n")
    for s in stmts {
      s.write(to: &stream, depth + 1)
    }
    if let expr = expr {
      expr.write(to: &stream, depth + 1)
    }
  }
}
