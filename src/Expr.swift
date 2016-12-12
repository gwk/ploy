// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: SubForm {

  case acc(Acc)
  case ann(Ann)
  case bind(Bind)
  case call(Call)
  //case cmpdType(CmpdType)
  case do_(Do)
  case fn(Fn)
  case hostVal(HostVal)
  case if_(If)
  case litNum(LitNum)
  case litStr(LitStr)
  case paren(Paren)
  case path(Path)
  case reify(Reify)
  case sig(Sig)
  case sym(Sym)

  init(form: Form, subj: String, exp: String) {
    if let form = form as? Acc            { self = .acc(form) }
    else if let form = form as? Ann       { self = .ann(form) }
    else if let form = form as? Bind      { self = .bind(form) }
    else if let form = form as? Call      { self = .call(form) }
    //else if let form = form as? CmpdType  { self = .cmpdType(form) }
    else if let form = form as? Do        { self = .do_(form) }
    else if let form = form as? Fn        { self = .fn(form) }
    else if let form = form as? HostVal   { self = .hostVal(form) }
    else if let form = form as? If        { self = .if_(form) }
    else if let form = form as? LitNum    { self = .litNum(form) }
    else if let form = form as? LitStr    { self = .litStr(form) }
    else if let form = form as? Paren     { self = .paren(form) }
    else if let form = form as? Path      { self = .path(form) }
    else if let form = form as? Reify     { self = .reify(form) }
    else if let form = form as? Sig       { self = .sig(form) }
    else if let form = form as? Sym       { self = .sym(form) }
    else {
      form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
    }
  }

  init(form: Form, subj: String) {
    self.init(form: form, subj: subj, exp: "expression")
  }

  var form: Form {
    switch self {
    case .acc(let acc): return acc
    case .ann(let ann): return ann
    case .bind(let bind): return bind
    case .call(let call): return call
    //case .cmpdType(let cmpdType): return cmpdType
    case .do_(let do_): return do_
    case .fn(let fn): return fn
    case .hostVal(let hostVal): return hostVal
    case .if_(let if_): return if_
    case .litNum(let litNum): return litNum
    case .litStr(let litStr): return litStr
    case .paren(let paren): return paren
    case .path(let path): return path
    case .reify(let reify): return reify
    case .sig(let sig): return sig
    case .sym(let sym): return sym
    }
  }

  var argLabel: Sym? {
    switch self {
    case .bind(let bind): return bind.place.sym
    default: return nil
    }
  }

  var parLabel: Sym? {
    switch self {
    case .ann(let ann): return ann.parLabel
    case .bind(let bind): return bind.place.sym
    case .sym(let sym): return sym
    default: return nil
    }
  }
}
