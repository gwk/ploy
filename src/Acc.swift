// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Acc: ActFormBase, ActForm { // accessor: `field@val`.
  let accessor: Accessor
  let accessee: Expr

  required init(_ syn: Syn, accessor: Accessor, accessee: Expr) {
    self.accessor = accessor
    self.accessee = accessee
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      accessor: Accessor.expect(l, subj: "access"),
      accessee: Expr.expect(r, subj: "access", exp: "accessee expression"))
  }

  // Form.

  static var expDesc: String { return "`@` access form" }

  var textTreeChildren: [Any] { return [accessor, accessee] }

  var cloned: Acc {
    return Acc(syn, accessor: accessor.cloned, accessee: accessee.cloned)
  }
}
