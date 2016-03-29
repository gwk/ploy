// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeConstraint {
  let actExpr: Expr
  let actType: Type
  let expForm: Form
  let expType: Type
  let desc: String
}


class TypeCtx {

  struct Error: ErrorType {
    let msg: String
    init(_ msg: String) {
      self.msg = msg
    }
  }

  private var constraints = [TypeConstraint]()
  private var freeTypes = [Type]()
  private var resolvedTypes = [Type:Type]() // maps all types containing free types to partially or completely resolved types.
  private var freeIndicesToUnresolvedTypes = DictOfSet<Int, Type>() // maps free types to all types containing them.
  private var exprOriginalTypes = [_Form:Type]() // maps forms to original types.
  private var isResolved = false

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()

  deinit { assert(isResolved) }

  func assertIsTracking(expr: Expr) { assert(exprOriginalTypes.contains(expr as! _Form)) }

  func originalTypeForExpr(expr: Form) -> Type { return exprOriginalTypes[expr as! _Form]! }

  func typeForExpr(expr: Expr) -> Type {
    let original = originalTypeForExpr(expr)
    return resolvedTypes[original].or(original)
  }

  func addFreeType() -> Type {
    let t = Type.Free(freeTypes.count)
    freeTypes.append(t)
    return t
  }

  func trackExpr(form: Form, type: Type) {
    exprOriginalTypes.insertNew(form as! _Form, value: type)
    trackFreeTypes(type)
  }

  func trackFreeTypes(type: Type) {
    for free in type.frees {
      guard case .Free(let index) = free.kind else { fatalError() }
      freeIndicesToUnresolvedTypes.insert(index, member: type)
    }
  }

  func constrain(actExpr: Expr, _ actType: Type, to expForm: Form, _ expType: Type, _ desc: String) {
    assert(originalTypeForExpr(actExpr) == actType)
    trackFreeTypes(expType)
    constraints.append(TypeConstraint(actExpr: actExpr, actType: actType, expForm: expForm, expType: expType, desc: desc))
  }

  func resolveType(type: Type, to resolved: Type) throws {
    if let existing = resolvedTypes[type] {
      if !existing.accepts(resolved) {
        throw Error("type resolution is not compatible with original")
      }
    }
    resolvedTypes[type] = resolved
    if case .Free(let index) = resolved.kind {
      let unresolvedTypes = freeIndicesToUnresolvedTypes[index].or([])
      for el in unresolvedTypes {
        let elResolved = el.refine(type, with: resolved)
        try resolveType(el, to: elResolved)
      }
      freeIndicesToUnresolvedTypes.removeValue(index)
    }
  }

  func resolveConstraint(constraint: TypeConstraint) throws {

    switch constraint.actType.kind {
    case .All(_ , _, _):
      throw Error("actual type cannot be of kind `All`")
    case .Any(_ , _, _):
      throw Error("actual type is of kind `Any`; unimplemented")
    case .Cmpd(_ , _, _): break
    case .Enum: break
    case .Free: break
    case .Host: break
    case .Prim: break
    case .Prop(_, _): break
    case .Sig(_, _, _, _): break
    case .Struct: break
    case .Var: break
    }
    if !constraint.actType.accepts(constraint.expType) {
      throw Error("constraint failed: \(constraint.desc)")
    }
  }

  func resolve() {

    for constraint in constraints {
      do {
        try resolveConstraint(constraint)
      } catch let e as Error {
        constraint.actExpr.failType(e.msg, notes: (constraint.expForm, "expected type"))
      } catch { fatalError() }
    }

    // check that resolution is complete.
    for type in freeTypes {
      guard let resolved = resolvedTypes[type] else {
        fatalError("unresolved free type: \(type)")
      }
      if case .Free = resolved.kind {
        fatalError("free type resolved to free type: \(type) -> \(resolved)")
      }
    }
    for (index, set) in freeIndicesToUnresolvedTypes {
      for type in set {
        errL("freeIndicesToUnResolvedType: \(index): \(type)")
      }
    }
    check(freeIndicesToUnresolvedTypes.isEmpty)
    isResolved = true
  }
}

