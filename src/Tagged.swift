// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


enum Tagged: SubForm { // syntax following tag `-`.

  case ann(Ann)
  case bind(Bind)
  case sym(Sym)


  init(form: Form, subj: String) {
    switch form {

    case let ann as Ann:
      guard case .sym = ann.expr else {
        ann.expr.form.failSyntax("\(subj) variant parameter (tagged annotation) expects symbol but received \(ann.expr.form.syntaxName).")
      }
      self = .ann(ann)

    case let bind as Bind:
      guard case .sym = bind.place else {
        bind.place.form.failSyntax("\(subj) morph constructor (tagged bind) expects symbol but received \(bind.place.form.syntaxName).")
      }
      self = .bind(bind)

    case let sym as Sym: self = .sym(sym)

    default:
      form.failSyntax("\(subj) expects symbol, annotated symbol, or variant constructor but received \(form.syntaxName).")
    }
  }


  var form: Form {
    switch self {
      case .ann(let ann): return ann
      case .bind(let bind): return bind
      case .sym(let sym): return sym
    }
  }


  var sym: Sym {
    switch self {
      case .ann(let ann):
        guard case .sym(let sym) = ann.expr else { fatalError() }
        return sym
      case .bind(let bind):
        guard case .sym(let sym) = bind.place else { fatalError() }
        return sym
      case .sym(let sym):
        return sym
    }
  }
}
