// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Place: SubForm { // left side of a binding.

  case ann(Ann)
  case sym(Sym)
  case tag(Tag)

  init?(form: Form) {
    switch form {
    case let ann as Ann:
      guard case .sym = ann.expr else {
        ann.expr.failSyntax("annnoted place expected symbol; received \(ann.expr.form.syntaxName).")
      }
      self = .ann(ann)
    case let sym as Sym: self = .sym(sym)
    case let tag as Tag: self = .tag(tag)
    default: return nil
    }
  }

  var form: Form {
    switch self {
    case .ann(let ann): return ann
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    }
  }

  static var parseExpDesc: String { return "symbol, annotated symbol, or tag" }

  var sym: Sym {
    switch self {
    case .ann(let ann):
      guard case .sym(let sym) = ann.expr else { fatalError() }
      return sym
    case .sym(let sym): return sym
    case .tag(let tag): return tag.sym
    }
  }

  var ann: Ann? {
    switch self {
    case .ann(let ann): return ann
    default: return nil
    }
  }

  var isTag: Bool {
    if case .tag = self { return true }
    return false
  }
}
