// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Identifier: SubForm {

  case path(SymPath)
  case sym(Sym)

  init?(form: Form) {
    switch form {
    case let f as SymPath: self = .path(f)
    case let f as Sym:  self = .sym(f)
    default: return nil
    }
  }

  var form: Form {
    switch self {
    case .path(let path): return path
    case .sym(let sym): return sym
    }
  }

  static var parseExpDesc: String { return "identifier symbol or path" }

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


