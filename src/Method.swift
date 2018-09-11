// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Method: ActFormBase, ActForm { // `+=` polyfunction extension definition.
  let place: Place
  let val: Expr

  init(_ syn: Syn, place: Place, val: Expr) {
    self.place = place
    self.val = val
    super.init(syn)
  }

  static func mk(l: ActForm, _ r: ActForm) -> ActForm {
    return Method(Syn(l.syn, r.syn),
      place: Place.expect(l, subj: "extension"),
      val: Expr.expect(r, subj: "extension", exp: "value expression"))
  }

  static var expDesc: String { return "`+=` extension" }

  var textTreeChildren: [Any] { return [place, val] }
}
