// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: Form { // value binding: `name=expr`.

  let place: Place
  let val: Expr

  init(_ syn: Syn, place: Place, val: Expr) {
    self.place = place
    self.val = val
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    let place = Place(form: l, subj: "binding")
    return Bind(Syn(l.syn, r.syn),
      place: place,
      val: Expr(form: r, subj: "binding", exp: "value expression"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    place.write(to: &stream, depth + 1)
    val.write(to: &stream, depth + 1)
  }

  var sym: Sym { return place.sym }
}
