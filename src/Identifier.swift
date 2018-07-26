// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Identifier: VaryingForm {

  case path(SymPath)
  case sym(Sym)

  static func accept(_ actForm: ActForm) -> Identifier? {
    switch actForm {
    case let f as SymPath: return .path(f)
    case let f as Sym:  return .sym(f)
    default: return nil
    }
  }

  var actForm: ActForm {
    switch self {
    case .path(let path): return path
    case .sym(let sym): return sym
    }
  }

  static var expDesc: String { return "identifier symbol or path" }

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


