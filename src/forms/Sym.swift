// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Expr, TypeExpr { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(name)
    target.write("\n")
  }

  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    return typeVal(scope.rec(self), subj)
  }

  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    return compile(em, depth, scope.rec(self), expType)
  }

  func typeVal(scopeRec: ScopeRec, _ subj: String) -> TypeVal {
    switch scopeRec.kind {
    case .Type(let typeVal): return typeVal
    default: fail("scope error", "\(subj) expected a type; `\(name)` refers to a value.")
    }
  }
  
  func compile(em: Emit, _ depth: Int, _ scopeRec: ScopeRec, _ expType: TypeVal) -> TypeVal {
    var typeVal: TypeVal! = nil
    switch scopeRec.kind {
    case .Val(let tv):
      typeVal = tv
      em.str(depth, scopeRec.hostString)
    case .Lazy(let tv):
      typeVal = tv
      em.str(depth, "\(scopeRec.hostString)__acc()")
    case .Space(_):
      fail("scope error", "expected a value; `\(name)` refers to a space.") // TODO: eventually this will return a runtime type.
    case .Type(_):
      fail("scope error", "expected a value; `\(name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    if !expType.accepts(typeVal) {
      fail("type error", "expected type `\(expType)`; `\(name)` has type `\(typeVal)`")
    }
    return typeVal
  }
  
  
  @noreturn func failUndef() { fail("scope error", "`\(name)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    fail("scope error", "redefinition of `\(name)`", original.map { ($0, "original definition here") })
  }
}

