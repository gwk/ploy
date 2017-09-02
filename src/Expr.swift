// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: SubForm, Hashable, CustomStringConvertible {

  case acc(Acc)
  case and(And)
  case ann(Ann)
  case bind(Bind)
  case call(Call)
  case do_(Do)
  case fn(Fn)
  case hostVal(HostVal)
  case if_(If)
  case litNum(LitNum)
  case litStr(LitStr)
  case magic(Magic)
  case match(Match)
  case or(Or)
  case paren(Paren)
  case path(Path)
  case reif(Reif)
  case sig(Sig)
  case sym(Sym)
  case tag(Tag)
  case tagTest(TagTest)
  case typeAlias(TypeAlias)
  case typeArgs(TypeArgs)
  case typeVar(TypeVar)
  case void(ImplicitVoid)
  case where_(Where)

  init(form: Form, subj: String, exp: String) {
    switch form {
    case let f as Acc:        self = .acc(f)
    case let f as And:        self = .and(f)
    case let f as Ann:        self = .ann(f)
    case let f as Bind:       self = .bind(f)
    case let f as Call:       self = .call(f)
    case let f as Do:         self = .do_(f)
    case let f as Fn:         self = .fn(f)
    case let f as HostVal:    self = .hostVal(f)
    case let f as If:         self = .if_(f)
    case let f as LitNum:     self = .litNum(f)
    case let f as LitStr:     self = .litStr(f)
    case let f as Match:      self = .match(f)
    case let f as Or:         self = .or(f)
    case let f as Paren:      self = .paren(f)
    case let f as Path:       self = .path(f)
    case let f as Reif:      self = .reif(f)
    case let f as Sig:        self = .sig(f)
    case let f as Sym:        self = .sym(f)
    case let f as Tag:        self = .tag(f)
    case let f as TagTest:    self = .tagTest(f)
    case let f as TypeAlias:  self = .typeAlias(f)
    case let f as TypeArgs:   self = .typeArgs(f)
    case let f as TypeVar:    self = .typeVar(f)
    case let f as Where:      self = .where_(f)
    default:
      form.failSyntax("\(subj) expected \(exp); received \(form.syntaxName).")
    }
  }

  init(form: Form, subj: String) {
    self.init(form: form, subj: subj, exp: "expression")
  }

  var form: Form {
    switch self {
    case .acc(let acc): return acc
    case .ann(let ann): return ann
    case .and(let and): return and
    case .bind(let bind): return bind
    case .call(let call): return call
    //case .typeConsraint(let typeConsraint): return typeConsraint
    case .do_(let do_): return do_
    case .fn(let fn): return fn
    case .hostVal(let hostVal): return hostVal
    case .if_(let if_): return if_
    case .litNum(let litNum): return litNum
    case .litStr(let litStr): return litStr
    case .magic(let magic): return magic
    case .match(let match): return match
    case .or(let or): return or
    case .paren(let paren): return paren
    case .path(let path): return path
    case .reif(let reif): return reif
    case .sig(let sig): return sig
    case .sym(let sym): return sym
    case .tag(let tag): return tag
    case .tagTest(let tagTest): return tagTest
    case .typeAlias(let typeAlias): return typeAlias
    case .typeArgs(let typeArgs): return typeArgs
    case .typeVar(let typeVar): return typeVar
    case .void(let void): return void
    case .where_(let where_): return where_
    }
  }

  var cloned: Expr {
    switch self {
    case .acc(let acc): return .acc(acc.cloned)
    case .litNum(let litNum): return .litNum(litNum.cloned)
    case .sym(let sym): return .sym(sym.cloned)
    case .tag(let tag): return .tag(tag.cloned)
    default: self.form.fatal("cannot clone expr: \(self)")
    }
  }

  static func ==(l: Expr, r: Expr) -> Bool { return l.form === r.form }

  var hashValue: Int { return form.hashValue }

  var description: String { return form.description }

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

  var isTagged: Bool {
    switch self {
      case .ann(let ann):
        if case .tag = ann.expr { return true }
        return false
      case .bind(let bind): return bind.place.isTag
      case .tag: return true
      default: return false
    }
  }

  var parenFieldEls: [Expr]? {
    switch self {
    case .paren(let paren): return paren.fieldEls
    default: return nil
    }
  }

  var parenVariantEls: [Expr]? {
    switch self {
    case .paren(let paren): return paren.variantEls
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

  func failSyntax(_ msg: String, notes: (Form?, String)...) -> Never {
    // redundant with form.failSyntax, but convenient so we do not have to type .form everywhere.
    form.failForm(prefix: "syntax error", msg: msg, notes: notes)
  }
}
