// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Accessor, Expr, TypeExpr { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }
  
  var description: String { return name }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(name)
    target.write("\n")
  }

  // MARK: Accessor
  
  var hostAccessor: String {
    return ".\(hostName)"
  }
  
  func compileAccess(em: Emit, _ depth: Int, accesseeType: TypeVal) -> TypeVal {
    em.str(depth, hostAccessor)
    if let accesseeType = accesseeType as? TypeValCmpd {
      for par in accesseeType.pars {
        if let label = par.label {
          if name == label.name {
            return par.typeVal
          }
        }
      }
      failType("symbol accessor does not match any parameter label of compound type: \(accesseeType)")
    } else {
      failType("symbol cannot access into value of type: \(accesseeType)")
    }
  }
  
  // MARK: Expr
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    return compileSym(em, depth, scope.rec(self), expType, isTail: isTail)
  }
  
  // MARK: TypeExpr
  
  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    return typeValRec(scope.rec(self), subj)
  }

  // MARK: Sym
  
  var hostName: String { return name.dashToUnder }
  
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
  
  func compileSym(em: Emit, _ depth: Int, _ scopeRec: ScopeRec, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    var typeVal: TypeVal! = nil
    switch scopeRec.kind {
    case .Val(let tv):
      typeVal = tv
      em.str(depth, isTail ? "{v:\(scopeRec.hostName)}" : scopeRec.hostName)
    case .Lazy(let tv):
      typeVal = tv
      let s = "\(scopeRec.hostName)__acc()"
      em.str(depth, isTail ? "{v:\(s)}" : "\(s)")
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

