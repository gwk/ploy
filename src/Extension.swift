// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Extension: Form { // extension definition.
  let place: Place
  let val: Expr

  init(_ syn: Syn, place: Place, val: Expr) {
    self.place = place
    self.val = val
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    let place = Place(form: l, subj: "extension")
    return Extension(Syn(l.syn, r.syn),
      place: place,
      val: Expr(form: r, subj: "extension", exp: "value expression"))
  }

  override var textTreeChildren: [Any] { return [place, val] }
}
