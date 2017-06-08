// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TagTest: Form { // accessor: `-tag@?val`.
  let tag: Tag
  let expr: Expr

  init(_ syn: Syn, tag: Tag, expr: Expr) {
    self.tag = tag
    self.expr = expr
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    guard let tag = l as? Tag else {
      l.failSyntax("tag test expects tag but received \(l.syntaxName).")
    }
    return TagTest(Syn(l.syn, r.syn),
      tag: tag,
      expr: Expr(form: r, subj: "tag test", exp: "tested expression"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    tag.write(to: &stream, depth + 1)
    expr.write(to: &stream, depth + 1)
  }
}