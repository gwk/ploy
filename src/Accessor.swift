// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Accessor: SubForm {

  case litNum(LitNum)
  case sym(Sym)
  case tag(Tag)
  case untag(Tag)

  init(form: Form, subj: String) {
    switch form {
    case let f as LitNum: self = .litNum(f)
    case let f as Sym:    self = .sym(f)
    case let f as Tag:    self = .tag(f)
    default:
      form.failSyntax("\(subj) expects accessor index, symbol, or tag; received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
    case .litNum(let litNum): return litNum
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    case .untag(let tag): return tag
    }
  }

  var cloned: Accessor {
    switch self {
    case .litNum(let litNum): return .litNum(litNum.cloned)
    case .sym(let sym): return .sym(sym.cloned)
    case .tag(let tag): return .tag(tag.cloned)
    case .untag(let tag): return .untag(tag.cloned)
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
    case .untag(let tag): fatalError("accessorString should never be called on untag: \(tag)")
    }
  }
}
