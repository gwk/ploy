// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: SubForm, Hashable {

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
  case void(ImplicitVoid)

  init(form: Form, subj: String, exp: String) {
    switch form {
    case let form as Acc:     self = .acc(form)
    case let form as Ann:     self = .ann(form)
    case let form as Bind:    self = .bind(form)
    case let form as Call:    self = .call(form)
    //case let form asCmpdType: self = .cmpdType(form)
    case let form as Do:      self = .do_(form)
    case let form as Fn:      self = .fn(form)
    case let form as HostVal: self = .hostVal(form)
    case let form as If:      self = .if_(form)
    case let form as LitNum:  self = .litNum(form)
    case let form as LitStr:  self = .litStr(form)
    case let form as Paren:   self = .paren(form)
    case let form as Path:    self = .path(form)
    case let form as Reify:   self = .reify(form)
    case let form as Sig:     self = .sig(form)
    case let form as Sym:     self = .sym(form)
    case let form as ImplicitVoid: self = .void(form)
    default:
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
    case .void(let void): return void
    }
  }

  var hashValue: Int { return form.hashValue }

  var argLabel: String? {
    switch self {
    case .bind(let bind): return bind.place.sym.name
    default: return nil
    }
  }

  var parLabel: String? {
    switch self {
    case .ann(let ann): return ann.parLabel
    case .bind(let bind): return bind.place.sym.name
    case .sym(let sym): return sym.name
    default: return nil
    }
  }
}

func ==(l: Expr, r: Expr) -> Bool { return l.form === r.form }
