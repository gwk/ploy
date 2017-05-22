// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: SubForm, Hashable, CustomStringConvertible {

  case acc(Acc)
  case ann(Ann)
  case bind(Bind)
  case call(Call)
  case do_(Do)
  case fn(Fn)
  case hostVal(HostVal)
  case if_(If)
  case litNum(LitNum)
  case litStr(LitStr)
  case match(Match)
  case paren(Paren)
  case path(Path)
  case reify(Reify)
  case sig(Sig)
  case sym(Sym)
  case tag(Tag)
  case typeAlias(TypeAlias)
  case void(ImplicitVoid)

  init(form: Form, subj: String, exp: String) {
    switch form {
    case let f as Acc:          self = .acc(f)
    case let f as Ann:          self = .ann(f)
    case let f as Bind:         self = .bind(f)
    case let f as Call:         self = .call(f)
    case let f as Do:           self = .do_(f)
    case let f as Fn:           self = .fn(f)
    case let f as HostVal:      self = .hostVal(f)
    case let f as If:           self = .if_(f)
    case let f as LitNum:       self = .litNum(f)
    case let f as LitStr:       self = .litStr(f)
    case let f as Match:        self = .match(f)
    case let f as Paren:        self = .paren(f)
    case let f as Path:         self = .path(f)
    case let f as Reify:        self = .reify(f)
    case let f as Sig:          self = .sig(f)
    case let f as Sym:          self = .sym(f)
    case let f as Tag:          self = .tag(f)
    case let f as TypeAlias:    self = .typeAlias(f)
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
    //case .typeConsraint(let typeConsraint): return typeConsraint
    case .do_(let do_): return do_
    case .fn(let fn): return fn
    case .hostVal(let hostVal): return hostVal
    case .if_(let if_): return if_
    case .litNum(let litNum): return litNum
    case .litStr(let litStr): return litStr
    case .match(let match): return match
    case .paren(let paren): return paren
    case .path(let path): return path
    case .reify(let reify): return reify
    case .sig(let sig): return sig
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    case .typeAlias(let typeAlias): return typeAlias
    case .void(let void): return void
    }
  }

  var hashValue: Int { return form.hashValue }

  var description: String { return "Expr(\(form))" }

  var sigDom: Expr? {
    switch self {
    case .fn(let fn): return fn.sig.dom
    case .sig(let sig): return sig.dom
    default: return nil
    }
  }

  var sigRet: Expr? {
    switch self {
    case .fn(let fn): return fn.sig.ret
    case .sig(let sig): return sig.ret
    default: return nil
    }
  }

  var structFields: [Expr]? {
    switch self {
    case .paren(let paren): return paren.els
    default: return nil
    }
  }

  var argLabel: String? {
    switch self {
    case .bind(let bind): return bind.place.sym.name
    default: return nil
    }
  }

  var parLabel: String? {
    switch self {
    case .ann(let ann):
      switch ann.expr {
      case .sym(let sym): return sym.name
      default: return nil
      }
    case .bind(let bind): return bind.place.sym.name
    case .sym: return nil // the symbol specifies the type, not the label.
    default: return nil
    }
  }

  static func ==(l: Expr, r: Expr) -> Bool { return l.form === r.form }
}
