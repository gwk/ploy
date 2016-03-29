// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Accessor, Expr, Identifier, TypeExpr { // symbol: `name`.
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

  // MARK: Accessor
  
  var hostAccessor: String {
    return ".\(hostName)"
  }

  var propAccessor: Type.PropAccessor {
    return .name(name)
  }

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type { // TODO: move to Prop type refinement.
    switch accesseeType.kind {
    case .cmpd(let pars, _, _):
      for par in pars {
        if let label = par.label {
          if name == label.name {
            return par.type
          }
        }
      }
      failType("symbol accessor does not match any parameter label of compound type: \(accesseeType)")
    default:
      failType("symbol cannot access into value of type: \(accesseeType)")
    }
  }

  func compileAccess(em: Emitter, _ depth: Int, accesseeType: Type) {
    em.str(depth, hostAccessor)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let record = scope.record(sym: self)
    let type = typeForExprRecord(record)
    ctx.trackExpr(self, type: type)
    ctx.symRecords[self] = record
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    compileSym(em, depth, ctx.symRecords[self]!, isTail: isTail)
  }

  // MARK: Identifier

  var syms: [Sym] { return [self] }
  
  func record(scope: Scope, _ sym: Sym) -> ScopeRecord {
    return scope.record(sym: self)
  }

  // MARK: TypeExpr

  func typeForTypeExpr(scope: Scope, _ subj: String) -> Type {
    return typeForTypeRecord(scope.record(sym: self), subj)
  }

  // MARK: Sym
  
  var hostName: String { return name.dashToUnder }
  
  func typeForExprRecord(scopeRecord: ScopeRecord) -> Type {
    switch scopeRecord.kind {
    case .lazy(let type): return type
    case .val(let type): return type
    default: failType("expression expects a value; `\(name)` refers to a \(scopeRecord.kind.kindDesc).")
    }
  }
  
  func typeForTypeRecord(scopeRecord: ScopeRecord, _ subj: String) -> Type {
    switch scopeRecord.kind {
    case .type(let type): return type
    default: failType("\(subj) expects a type; `\(name)` refers to a \(scopeRecord.kind.kindDesc).")
    }
  }
  
  func compileSym(em: Emitter, _ depth: Int, _ scopeRecord: ScopeRecord, isTail: Bool) {
    switch scopeRecord.kind {
    case .val:
      em.str(depth, isTail ? "{v:\(scopeRecord.hostName)}" : scopeRecord.hostName)
    case .lazy:
      let s = "\(scopeRecord.hostName)__acc()"
      em.str(depth, isTail ? "{v:\(s)}" : "\(s)")
    case .fwd:
      failType("expected a value; `\(name)` refers to a forward declaration. INTERNAL ERROR?")
    case .polyFn:
      em.str(depth, isTail ? "{v:\(scopeRecord.hostName)}" : scopeRecord.hostName)
    case .space(_):
      failType("expected a value; `\(name)` refers to a namespace.") // TODO: eventually this will return a runtime namespace?
    case .type(_):
      failType("expected a value; `\(name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
  }
  
  @noreturn func failUndef() { failForm("scope error", msg: "`\(name)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    failForm("scope error", msg: "redefinition of `\(name)`", notes: (original, "original definition here"))
  }
}

