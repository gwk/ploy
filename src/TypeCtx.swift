// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


class TypeCtx {

  struct Err: Error {
    let constraint: Constraint
    let msg: String

    init(_ constraint: Constraint, _ msg: String) {
      self.constraint = constraint
      self.msg = msg
    }
  }

  private var constraints: [Constraint] = []
  private var freeTypes: [Type] = []
  private var resolvedTypes: [Type:Type] = [:] // maps all types containing free types to partially or completely resolved types.
  private var freeIndicesToUnresolvedTypes: DictOfSet<Int, Type> = [:] // maps free types to all types containing them.
  private var exprOriginalTypes = [Form:Type]() // maps forms to original types.
  private var isResolved = false

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()

  deinit { assert(isResolved) }


  func assertIsTracking(_ expr: Expr) { assert(exprOriginalTypes.contains(key: expr.form)) }

  func originalTypeForExpr(_ expr: Expr) -> Type { return exprOriginalTypes[expr.form]! }


  func resolvedType(_ type: Type) -> Type {
    return resolvedTypes[type].or(type)
  }


  func typeFor(expr: Expr) -> Type {
    return resolvedType(originalTypeForExpr(expr))
  }


  func addFreeType() -> Type {
    let t = Type.Free(freeTypes.count)
    freeTypes.append(t)
    return t
  }


  func trackExpr(_ expr: Expr, type: Type) {
    exprOriginalTypes.insertNew(expr.form, value: type)
    trackFreeTypes(type)
  }


  func trackFreeTypes(_ type: Type) {
    for free in type.frees {
      guard case .free(let index) = free.kind else { fatalError() }
      freeIndicesToUnresolvedTypes.insert(index, member: type)
    }
  }


  func constrain(_ actExpr: Expr, expForm: Form, expType: Type, _ desc: String) {
    trackFreeTypes(expType)
    constraints.append(Constraint(
      actForm: actExpr.form, actType: originalTypeForExpr(actExpr), actChain: .end,
      expForm: expForm, expType: expType, expChain: .end, desc: desc))
  }


  func constrain(form: Form, type: Type, expForm: Form, expType: Type, _ desc: String) {
    trackFreeTypes(expType)
    constraints.append(Constraint(
      actForm: form, actType: type, actChain: .end,
      expForm: expForm, expType: expType, expChain: .end, desc: desc))
  }


  func resolveType(_ type: Type, to resolved: Type) {
    if let existing = resolvedTypes[type] {
      fatalError("multiple resolutions not yet supported;\n  original: \(type)\n  existing: \(existing)\n  incoming: \(resolved)")
    }
    resolvedTypes[type] = resolved
    if case .free(let index) = resolved.kind {
      let unresolvedTypes = (freeIndicesToUnresolvedTypes[index]?.val).or([])
      for el in unresolvedTypes {
        let elResolved = el.refine(type, with: resolved)
        resolveType(el, to: elResolved)
      }
      _ = freeIndicesToUnresolvedTypes.removeValue(index)
    }
  }


  func resolveFreeType(_ freeType: Type, to resolved: Type) {
    // just for clarity / as an experiment, always prefer lower free indices.
    if case .free(let resolvedIndex) = resolved.kind {
      if freeType.freeIndex > resolvedIndex {
        resolveType(freeType, to: resolved)
      } else {
        resolveType(resolved, to: freeType)
      }
    } else {
      resolveType(freeType, to: resolved)
    }
  }


  func resolveConstraint(_ constraint: Constraint) {
    let actType = resolvedType(constraint.actType)
    let expType = resolvedType(constraint.expType)
    if (actType == expType) {
      return
    }

    switch actType.kind {

    case .free:
      resolveFreeType(actType, to: expType)
      return

    default: break
    }

    switch expType.kind {

    case .all(_, _, _):
      constraint.fail(act: actType, exp: expType, "expected type of kind `All` not yet implemented")

    case .any(let members, _, _):
      if !members.contains(actType) {
        constraint.fail(act: actType, exp: expType, "actual type is not a member of `Any` expected type")
      }

    case .cmpd:
      resolveConstraintToCmpd(constraint, actType: actType, expType: expType)

    case .enum_:
      constraint.fail(act: actType, exp: expType, "enum constraints not implemented")

    case .free:
      resolveType(expType, to: actType)

    case .host, .prim:
      resolveConstraintToOpaque(constraint, actType: actType, expOpaqueType: expType)

    case .prop(_, _):
      constraint.fail(act: actType, exp: expType, "prop constraints not implemented")

    case .sig:
      resolveConstraintToSig(constraint, act: actType, exp: expType)

    case .struct_:
      constraint.fail(act: actType, exp: expType, "struct constraints not implemented")

    case .var_:
      constraint.fail(act: actType, exp: expType, "var constraints not implemented")
    }
  }


  func resolveConstraintToCmpd(_ constraint: Constraint, actType: Type, expType: Type) {
    guard case .cmpd(let expPars, _, _) = expType.kind else { fatalError() }

    switch actType.kind {

    case .cmpd(let actPars, _, _):
      if expPars.count != actPars.count {
        let actFields = pluralize(actPars.count, "field")
        constraint.fail(act: actType, exp: expType, "actual compound type has \(actFields); expected \(expPars.count).")
      }
      for (actPar, expPar) in zip(actPars, expPars) {
        if actPar.label?.name != expPar.label?.name {
          constraint.fail(act: actType, exp: expType,
            "compound field #\(actPar.index) has \(actPar.labelMsg); expected \(expPar.labelMsg).")
        }
        let index = actPar.index
        resolveSub(constraint,
          actType: actPar.type, actDesc: "compound field \(index)",
          expType: expPar.type, expDesc: "compound field \(index)")
      }
      return

    default: constraint.fail(act: actType, exp: expType, "actual type is not a compound")
    }
  }


  func resolveConstraintToOpaque(_ constraint: Constraint, actType: Type, expOpaqueType: Type) {
    switch actType.kind {
    case .prop(let accessor, let accesseeType):
      switch accesseeType.kind {
      case .cmpd(let pars, _, _):
        for par in pars {
          if par.accessorString == accessor.accessorString {
            resolveSub(constraint,
              actType: par.type, actDesc: "`\(par.accessorString)` property",
              expType: expOpaqueType, expDesc: nil)
            return
          }
        }
        constraint.fail(act: accesseeType, exp: expOpaqueType, "actual type has no field matching accessor") // TODO: this should be caught earlier.
      default: constraint.fail(act: accesseeType, exp: expOpaqueType, "actual type is not an accessible type")
      }
    default: constraint.fail(act: actType, exp: expOpaqueType, "actual type is not expected opaque type")
    }
  }


  func resolveConstraintToSig(_ constraint: Constraint, act: Type, exp: Type) {
    guard case .sig(let expSig) = exp.kind else { fatalError() }
    switch act.kind {
    case .sig(let actSig):
      resolveSub(constraint,
        actType: actSig.send, actDesc: "signature parameter",
        expType: expSig.send, expDesc: "signature parameter")
      resolveSub(constraint,
        actType: actSig.ret, actDesc: "signature return",
        expType: expSig.ret, expDesc: "signature return")
      return
    default: constraint.fail(act: act, exp: exp, "actual type is not a signature")
    }
  }


  func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String?, expType: Type, expDesc: String?) {
    resolveConstraint(constraint.subConstraint(
      actType: actType, actDesc: actDesc,
      expType: expType, expDesc: expDesc))
  }


  func resolve() {

    for constraint in constraints {
      resolveConstraint(constraint)
    }

    // check that resolution is complete.
    for type in freeTypes {
      guard let resolved = resolvedTypes[type] else {
        fatalError("unresolved free type: \(type)")
      }
      if case .free = resolved.kind {
        fatalError("free type resolved to free type: \(type) -> \(resolved)")
      }
    }
    for (index, set) in freeIndicesToUnresolvedTypes {
      for type in set.val {
        errL("freeIndicesToUnResolvedType: \(index): \(type)")
      }
    }
    check(freeIndicesToUnresolvedTypes.isEmpty)
    isResolved = true
  }
}
