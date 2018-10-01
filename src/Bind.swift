// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: ActFormBase, ActForm { // value binding: `name=expr`.
  let place: Place
  let val: Expr

  required init(_ syn: Syn, place: Place, val: Expr) {
    self.place = place
    self.val = val
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return self.init(Syn(l.syn, r.syn),
      place: Place.expect(l, subj: "binding"),
      val: Expr.expect(r, subj: "binding", exp: "value expression"))
  }

  static var expDesc: String { return "`=` binding" }

  var textTreeChildren: [Any] { return [place, val] }
}
