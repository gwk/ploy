// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Accessor: SubForm {

  case litNum(LitNum)
  case sym(Sym)

  init(form: Form, subj: String) {
    switch form {
    case let f as LitNum: self = .litNum(f)
    case let f as Sym:    self = .sym(f)
    default:
      form.failSyntax("\(subj) expects accessor symbol or number literal but received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
    case .litNum(let litNum): return litNum
    case .sym(let sym): return sym
    }
  }

  var hostAccessor: String {
    switch self {
    case .litNum(let litNum): return "._\(litNum.val)"
    case .sym(let sym): return ".\(sym.hostName)"
    }
  }

  var accessorString: String {
    switch self {
    case .litNum(let litNum): return String(litNum.val)
    case .sym(let sym): return sym.name
    }
  }
}
