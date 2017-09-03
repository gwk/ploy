// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Reif: Form { // type reification:  `T<A>`.
  let abstract: Expr
  let args: TypeArgs

  required init(_ syn: Syn, abstract: Expr, args: TypeArgs) {
    self.abstract = abstract
    self.args = args
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      abstract: Expr(form: l, subj: "type reification"),
      args: r as! TypeArgs)
  }

  override var textTreeChildren: [Any] { return [abstract, args] }
}
