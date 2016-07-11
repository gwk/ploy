// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Identifier: SubForm {

  case path(Path)
  case sym(Sym)

  init(form: Form, subj: String, exp: String) {
    if let form = form as? Path     { self = .path(form) }
    else if let form = form as? Sym { self = .sym(form) }
    else {
      form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
    }
  }

  init(form: Form, subj: String) {
    self.init(form: form, subj: subj, exp: "identifier")
  }

  var form: Form {
    switch self {
    case .path(let path): return path
    case .sym(let sym): return sym
    }
  }

  var name: String {
    return syms.map({$0.name}).joined(separator: "/")
  }

  var syms: [Sym] {
    switch self {
      case .path(let path): return path.syms
      case .sym(let sym): return [sym]
    }
  }
}


