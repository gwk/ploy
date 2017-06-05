// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Accessor: SubForm {

  case litNum(LitNum)
  case sym(Sym)
  case tag(Tag)
  case untag(Sym)

  init(form: Form, subj: String) {
    switch form {
    case let f as LitNum: self = .litNum(f)
    case let f as Sym:    self = .sym(f)
    case let f as Tag:    self = .tag(f)
    default:
      form.failSyntax("\(subj) expects accessor symbol or number literal but received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
    case .litNum(let litNum): return litNum
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    case .untag(let sym): return sym
    }
  }

  var hostAccessor: String {
    switch self {
    case .litNum(let litNum): return "._\(litNum.val)"
    case .sym(let sym): return ".\(sym.hostName)"
    case .tag: fatalError("tag accessors not yet implemented")
    case .untag: return  ".$m"
    }
  }

  var accessorString: String {
    switch self {
    case .litNum(let litNum): return String(litNum.val)
    case .sym(let sym): return sym.name
    case .tag(let tag): return "-\(tag.sym.name)"
    case .untag(let sym): fatalError("accessorString should never be called on untag: \(sym)")
    }
  }
}
