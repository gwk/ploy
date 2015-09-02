// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Expr, TypeExpr { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }
  
  var hostName: String { return name.dashToUnder }
    
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(name)
    target.write("\n")
  }

  // MARK: Expr
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    return compileSym(em, depth, scope.rec(self), expType)
  }
  
  // MARK: TypeExpr
  
  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    return typeValRec(scope.rec(self), subj)
  }

  // MARK: Sym
  
  func typeValForExprRec(scopeRec: ScopeRec, _ subj: String) -> TypeVal {
    switch scopeRec.kind {
    case .Val(let typeVal): return typeVal
    case .Lazy(let typeVal): return typeVal
    default: failType("\(subj) expects a value; `\(name)` refers to a \(scopeRec.kind.kindDesc).")
    }
  }
  
  func typeValRec(scopeRec: ScopeRec, _ subj: String) -> TypeVal {
    switch scopeRec.kind {
    case .Type(let typeVal): return typeVal
    default: failType("\(subj) expects a type; `\(name)` refers to a \(scopeRec.kind.kindDesc).")
    }
  }
  
  func compileSym(em: Emit, _ depth: Int, _ scopeRec: ScopeRec, _ expType: TypeVal) -> TypeVal {
    var typeVal: TypeVal! = nil
    switch scopeRec.kind {
    case .Val(let tv):
      typeVal = tv
      em.str(depth, scopeRec.hostName)
    case .Lazy(let tv):
      typeVal = tv
      em.str(depth, "(\(scopeRec.hostName)__acc())") // TODO: are parentheses necessary?
    case .Space(_):
      failType("expected a value; `\(name)` refers to a space.") // TODO: eventually this will return a runtime type.
    case .Type(_):
      failType("expected a value; `\(name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    if !expType.accepts(typeVal) {
      failType("expected type `\(expType)`; `\(name)` has type `\(typeVal)`")
    }
    return typeVal
  }
  
  @noreturn func failUndef() { failForm("scope error", msg: "`\(name)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    failForm("scope error", msg: "redefinition of `\(name)`", notes: (original, "original definition here"))
  }
}

