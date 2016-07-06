// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: Form { // value binding: `name=expr`.

  enum Name {
    case sym(Sym)
    case ann(Ann)

    var sym: Sym {
      switch self {
        case sym(let sym): return sym
        case ann(let ann):
          guard case .sym(let sym) = ann.expr else { fatalError() }
          return sym
      }
    }
  }

  let name: Name
  let val: Expr
  
  init(_ syn: Syn, name: Name, val: Expr) {
    self.name = name
    self.val = val
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    let name: Name
    if let sym = l as? Sym {
      name = .sym(sym)
    }
    else if let ann = l as? Ann {
      guard case .sym = ann.expr else {
        ann.expr.form.failSyntax("annotated binding name expects name symbol but received \(ann.expr.form.syntaxName).")
      }
      name = .ann(ann)
    } else {
      l.failSyntax("binding name expects name symbol or annotated name symbol but received \(l.syntaxName).")
    }
    return Bind(Syn(l.syn, r.syn),
      name: name,
      val: Expr(form: r, subj: "binding", exp: "value expression"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    val.write(to: &stream, depth + 1)
  }

  var sym: Sym { return name.sym }
}

