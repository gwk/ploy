// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TagTest: ActFormBase, ActForm { // accessor: `-tag@?val`.
  let tag: Tag
  let expr: Expr

  required init(_ syn: Syn, tag: Tag, expr: Expr) {
    self.tag = tag
    self.expr = expr
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      tag: Tag.expect(l, subj: "tag test"),
      expr: Expr.expect(r, subj: "tag test", exp: "tested expression"))
  }

  static var expDesc: String { return "`@?` tag test" }

  var textTreeChildren: [Any] { return [tag, expr] }
}
