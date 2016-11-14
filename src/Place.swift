// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Place: SubForm { // left side of a binding.

  case ann(Ann)
  case sym(Sym)

  init(form: Form, subj: String) {
    if let form = form as? Ann {
      guard case .sym = form.expr else {
        let expr = form.expr
        form.failSyntax("\(subj) annnoted place expects symbol but received \(expr.form.syntaxName).")
      }
      self = .ann(form)
    } else if let form = form as? Sym {
      self = .sym(form)
    } else {
      form.failSyntax("\(subj) expects symbol or annotated symbol but received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
      case .sym(let sym): return sym
      case .ann(let ann): return ann
    }
  }

  var sym: Sym {
    switch self {
      case .sym(let sym): return sym
      case .ann(let ann):
        guard case .sym(let sym) = ann.expr else { fatalError() }
        return sym
    }
  }
}
