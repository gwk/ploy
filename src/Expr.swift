// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: VaryingForm, Hashable, CustomStringConvertible {

  case acc(Acc)
  case and(And)
  case ann(Ann)
  case bind(Bind)
  case call(Call)
  case do_(Do)
  case fn(Fn)
  case hostVal(HostVal)
  case if_(If)
  case intersection(Intersection)
  case litNum(LitNum)
  case litStr(LitStr)
  case magic(Magic)
  case match(Match)
  case or(Or)
  case paren(Paren)
  case path(SymPath)
  case reif(Reif)
  case sig(Sig)
  case sym(Sym)
  case tag(Tag)
  case tagTest(TagTest)
  case typeAlias(TypeAlias)
  case typeArgs(TypeArgs)
  case typeReq(TypeReq)
  case typeVarDecl(TypeVarDecl)
  case union(Union)
  case void(ImplicitVoid)
  case where_(Where)

  static func accept(_ actForm: ActForm) -> Expr? {
    switch actForm {
    case let f as Acc:          return .acc(f)
    case let f as And:          return .and(f)
    case let f as Ann:          return .ann(f)
    case let f as Bind:         return .bind(f)
    case let f as Call:         return .call(f)
    case let f as Do:           return .do_(f)
    case let f as Fn:           return .fn(f)
    case let f as HostVal:      return .hostVal(f)
    case let f as If:           return .if_(f)
    case let f as Intersection: return .intersection(f)
    case let f as LitNum:       return .litNum(f)
    case let f as LitStr:       return .litStr(f)
    case let f as Match:        return .match(f)
    case let f as Or:           return .or(f)
    case let f as Paren:        return .paren(f)
    case let f as SymPath:      return .path(f)
    case let f as Reif:         return .reif(f)
    case let f as Sig:          return .sig(f)
    case let f as Sym:          return .sym(f)
    case let f as Tag:          return .tag(f)
    case let f as TagTest:      return .tagTest(f)
    case let f as TypeAlias:    return .typeAlias(f)
    case let f as TypeArgs:     return .typeArgs(f)
    case let f as TypeReq:      return .typeReq(f)
    case let f as TypeVarDecl:  return .typeVarDecl(f)
    case let f as Union:        return .union(f)
    case let f as Where:        return .where_(f)
    default:  return nil
    }
  }

  var actForm: ActForm {
    switch self {
    case .acc(let acc): return acc
    case .ann(let ann): return ann
    case .and(let and): return and
    case .bind(let bind): return bind
    case .call(let call): return call
    case .do_(let do_): return do_
    case .fn(let fn): return fn
    case .hostVal(let hostVal): return hostVal
    case .if_(let if_): return if_
    case .intersection(let intersection): return intersection
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
    case .typeReq(let typeReq): return typeReq
    case .typeVarDecl(let typeVarDecl): return typeVarDecl
    case .union(let union): return union
    case .void(let void): return void
    case .where_(let where_): return where_
    }
  }

  static var expDesc: String { return "expression" }

  var cloned: Expr {
    switch self {
    case .acc(let acc): return .acc(acc.cloned)
    case .litNum(let litNum): return .litNum(litNum.cloned)
    case .sym(let sym): return .sym(sym.cloned)
    case .tag(let tag): return .tag(tag.cloned)
    default: self.fatal("cannot clone expr: \(self)")
    }
  }

  var identifierLastSym: Sym {
    switch self {
    case .path(let path): return path.syms.last!
    case .sym(let sym): return sym
    default: self.fatal("not an identifier: \(self)")
    }
  }

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

  var parenMembers: [Expr]? {
    switch self {
    case .paren(let paren): return paren.els
    default: return nil
    }
  }

  var argLabel: String? {
    switch self {
    case .bind(let bind): return bind.place.sym.name
    case .tag(let tag): return tag.sym.name
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
}
