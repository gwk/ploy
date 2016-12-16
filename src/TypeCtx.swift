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
    let act = resolvedType(constraint.actType)
    let exp = resolvedType(constraint.expType)
    if (act == exp) {
      return
    }

    switch act.kind {

    case .free:
      resolveFreeType(act, to: exp)
      return

    default: break
    }

    switch exp.kind {

    case .all(_):
      constraint.fail(act: act, exp: exp, "expected type of kind `All` not yet implemented")

    case .any(let members):
      if !members.contains(act) {
        constraint.fail(act: act, exp: exp, "actual type is not a member of `Any` expected type")
      }

    case .cmpd:
      resolveConstraintToCmpd(constraint, act: act, exp: exp)

    case .free:
      resolveType(exp, to: act)

    case .host, .prim:
      resolveConstraintToOpaque(constraint, act: act, exp: exp)

    case .prop(_, _):
      constraint.fail(act: act, exp: exp, "prop constraints not implemented")

    case .sig:
      resolveConstraintToSig(constraint, act: act, exp: exp)

    case .var_:
      constraint.fail(act: act, exp: exp, "var constraints not implemented")
    }
  }


  func resolveConstraintToCmpd(_ constraint: Constraint, act: Type, exp: Type) {
    guard case .cmpd(let expFields) = exp.kind else { fatalError() }

    switch act.kind {

    case .cmpd(let actFields):
      if expFields.count != actFields.count {
        let actFields = pluralize(actFields.count, "field")
        constraint.fail(act: act, exp: exp, "actual compound type has \(actFields); expected \(expFields.count).")
      }
      for (actField, expField) in zip(actFields, expFields) {
        if actField.label != expField.label {
          constraint.fail(act: act, exp: exp,
            "compound field #\(actField.index) has \(actField.labelMsg); expected \(expField.labelMsg).")
        }
        let index = actField.index
        resolveSub(constraint,
          actType: actField.type, actDesc: "compound field \(index)",
          expType: expField.type, expDesc: "compound field \(index)")
      }
      return

    default: constraint.fail(act: act, exp: exp, "actual type is not a compound")
    }
  }


  func resolveConstraintToOpaque(_ constraint: Constraint, act: Type, exp: Type) {
    switch act.kind {
    case .prop(let accessor, let accesseeType):
      switch accesseeType.kind {
      case .cmpd(let fields):
        for field in fields {
          if field.accessorString == accessor.accessorString {
            resolveSub(constraint,
              actType: field.type, actDesc: "`\(field.accessorString)` property",
              expType: exp, expDesc: nil)
            return
          }
        }
        constraint.fail(act: accesseeType, exp: exp, "actual type has no field matching accessor") // TODO: this should be caught earlier.
      default: constraint.fail(act: accesseeType, exp: exp, "actual type is not an accessible type")
      }
    default: constraint.fail(act: act, exp: exp, "actual type is not expected opaque type")
    }
  }


  func resolveConstraintToSig(_ constraint: Constraint, act: Type, exp: Type) {
    guard case .sig(let expSend, let expRet) = exp.kind else { fatalError() }
    switch act.kind {
    case .sig(let actSend, let actRet):
      resolveSub(constraint,
        actType: actSend, actDesc: "signature send",
        expType: expSend, expDesc: "signature send")
      resolveSub(constraint,
        actType: actRet, actDesc: "signature return",
        expType: expRet, expDesc: "signature return")
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
