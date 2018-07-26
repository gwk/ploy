// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TagTest: ActFormBase, ActForm { // accessor: `-tag@?val`.
  let tag: Tag
  let expr: Expr

  init(_ syn: Syn, tag: Tag, expr: Expr) {
    self.tag = tag
    self.expr = expr
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    guard let tag = l as? Tag else {
      l.failSyntax("tag test expected tag; received \(l.actDesc).")
    }
    return TagTest(Syn(l.syn, r.syn),
      tag: tag,
      expr: Expr.expect(r, subj: "tag test", exp: "tested expression"))
  }

  static var expDesc: String { return "`@?` tag test" }

  var textTreeChildren: [Any] { return [tag, expr] }
}
