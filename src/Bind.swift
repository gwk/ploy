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
    let place: Place
    if let sym = l as? Sym {
      place = .sym(sym)
    }
    else if let ann = l as? Ann {
      guard case .sym = ann.expr else {
        ann.expr.form.failSyntax("annotated binding name expects name symbol but received \(ann.expr.form.syntaxName).")
      }
      place = .ann(ann)
    } else {
      l.failSyntax("binding name expects name symbol or annotated name symbol but received \(l.syntaxName).")
    }
    return Bind(Syn(l.syn, r.syn),
      place: place,
      val: Expr(form: r, subj: "binding", exp: "value expression"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    place.write(to: &stream, depth + 1)
    val.write(to: &stream, depth + 1)
  }

  var sym: Sym { return place.sym }
}

