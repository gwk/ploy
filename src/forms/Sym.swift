// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Accessor, Expr, Identifier, TypeExpr { // symbol: `name`.
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
  
  func compileAccess(em: Emit, _ depth: Int, accesseeType: Type) -> Type {
    em.str(depth, hostAccessor)
    if let accesseeType = accesseeType as? TypeCmpd {
      for par in accesseeType.pars {
        if let label = par.label {
          if name == label.name {
            return par.type
          }
        }
      }
      failType("symbol accessor does not match any parameter label of compound type: \(accesseeType)")
    } else {
      failType("symbol cannot access into value of type: \(accesseeType)")
    }
  }
  
  // MARK: Expr
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: Type, isTail: Bool) -> Type {
    return compileSym(em, depth, scope.rec(self), expType, isTail: isTail)
  }
  
  // MARK: TypeExpr
  
  func typeVal(scope: Scope, _ subj: String) -> Type {
    return typeValForTypeRecord(scope.rec(self), subj)
  }

  // MARK: Sym
  
  var hostName: String { return name.dashToUnder }
  
  func typeValForExprRecord(scopeRecord: ScopeRecord, _ subj: String) -> Type {
    switch scopeRecord.kind {
    case .Val(let type): return type
    case .Lazy(let type): return type
    default: failType("\(subj) expects a value; `\(name)` refers to a \(scopeRecord.kind.kindDesc).")
    }
  }
  
  func typeValForTypeRecord(scopeRecord: ScopeRecord, _ subj: String) -> Type {
    switch scopeRecord.kind {
    case .Type(let type): return type
    default: failType("\(subj) expects a type; `\(name)` refers to a \(scopeRecord.kind.kindDesc).")
    }
  }
  
  func compileSym(em: Emit, _ depth: Int, _ scopeRecord: ScopeRecord, _ expType: Type, isTail: Bool) -> Type {
    var type: Type! = nil
    switch scopeRecord.kind {
    case .Val(let t):
      type = t
      em.str(depth, isTail ? "{v:\(scopeRecord.hostName)}" : scopeRecord.hostName)
    case .Lazy(let t):
      type = t
      let s = "\(scopeRecord.hostName)__acc()"
      em.str(depth, isTail ? "{v:\(s)}" : "\(s)")
    case .Space(_):
      failType("expected a value; `\(name)` refers to a space.") // TODO: eventually this will return a runtime type.
    case .Type(_):
      failType("expected a value; `\(name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    if !expType.accepts(type) {
      failType("expected type `\(expType)`; `\(name)` has type `\(typeVal)`")
    }
    return type
  }
  
  @noreturn func failUndef() { failForm("scope error", msg: "`\(name)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    failForm("scope error", msg: "redefinition of `\(name)`", notes: (original, "original definition here"))
  }
}

