// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Reif: ActFormBase, ActForm { // type reification:  `T<A>`.
  let abstract: Identifier
  let args: TypeArgs

  required init(_ syn: Syn, abstract: Identifier, args: TypeArgs) {
    self.abstract = abstract
    self.args = args
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      abstract: Identifier.expect(l, subj: "type reification"),
      args: TypeArgs.expect(r, subj: "type reification"))
  }

  static var expDesc: String { return "type reification" }

  var textTreeChildren: [Any] { return [abstract, args] }
}
