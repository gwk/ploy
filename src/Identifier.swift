// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Identifier: SubForm {

  case path(Path)
  case sym(Sym)

  init(form: Form, subj: String) {
    switch form {
    case let f as Path: self = .path(f)
    case let f as Sym:  self = .sym(f)
    default:
      form.failSyntax("\(subj) expects identifier symbol or path but received \(form.syntaxName).")
    }
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


