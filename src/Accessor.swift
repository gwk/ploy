// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Accessor: SubForm {

  case litNum(LitNum)
  case sym(Sym)

  init(form: Form, subj: String) {
    if let form = form as? LitNum {
      self = .litNum(form)
    } else if let form = form as? Sym {
      self = .sym(form)
    } else {
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

  var propAccessor: Type.PropAccessor {
    switch self {
      case .litNum(let litNum): return .index(litNum.val)
      case .sym(let sym): return .name(sym.name)
    }
  }
}
