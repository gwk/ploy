// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Paren: Form { // parenthesized expression: `(a)`.
  let expr: Expr

  init(_ syn: Syn, expr: Expr) {
    self.expr = expr
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    expr.write(to: &stream, depth + 1)
  }
}
