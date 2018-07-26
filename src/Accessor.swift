// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Accessor: VaryingForm {

  case litNum(LitNum)
  case sym(Sym)
  case tag(Tag)
  case untag(Tag)

  static func accept(_ actForm: ActForm) -> Accessor? {
    switch actForm {
    case let f as LitNum: return .litNum(f)
    case let f as Sym:    return .sym(f)
    case let f as Tag:    return .tag(f)
    default: return nil
    }
  }

  var actForm: ActForm {
    switch self {
    case .litNum(let litNum): return litNum
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    case .untag(let tag): return tag
    }
  }

  static var expDesc: String { return "index, symbol, or tag accessor" }

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
    case .untag(let tag): return  ".\(tag.sym.hostName)"
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
