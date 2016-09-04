// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Place: SubForm { // left side of a binding.

  case sym(Sym)
  case ann(Ann)


  init(form: Form, subj: String) {
    if let form = form as? Sym {
      self = .sym(form)
    } else if let form = form as? Ann {
      self = .ann(form)
    } else {
      form.failSyntax("\(subj) expects accessor symbol or number literal but received \(form.syntaxName).")
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
