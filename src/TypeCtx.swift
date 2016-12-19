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
  private var exprSubtypes = [Form:Type]() // maps forms to legal, inferred compile time narrowing.
  private var exprConversions = [Form:Conversion]() // maps forms to legal, inferred runtime conversions.
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
    let type = exprSubtypes[expr.form].or(originalTypeForExpr(expr))
    return resolvedType(type)
  }


  func conversionFor(expr: Expr) -> Conversion? {
    return exprConversions[expr.form]
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


  func resolveType(_ type: Type, to resolved: Type) -> String? {
    if let existing = resolvedTypes[type] {
      return "multiple resolutions not yet supported;\n  original: \(type)\n  existing: \(existing)\n  incoming: \(resolved)"
    }
    resolvedTypes[type] = resolved
    if case .free(let index) = resolved.kind {
      let unresolvedTypes = (freeIndicesToUnresolvedTypes[index]?.val).or([])
      for el in unresolvedTypes {
        let elResolved = el.refine(type, with: resolved)
        if let msg = resolveType(el, to: elResolved) { return msg }
      }
      _ = freeIndicesToUnresolvedTypes.removeValue(index)
    }
    return nil
  }


  func resolveFreeType(_ freeType: Type, to resolved: Type) -> String? {
    // just for clarity / as an experiment, always prefer lower free indices.
    if case .free(let resolvedIndex) = resolved.kind {
      if freeType.freeIndex > resolvedIndex {
        return resolveType(freeType, to: resolved)
      } else {
        return resolveType(resolved, to: freeType)
      }
    } else {
      return resolveType(freeType, to: resolved)
    }
  }


  func resolveConstraint(_ constraint: Constraint) -> (Constraint, String)? {
    let act = resolvedType(constraint.actType)
    let exp = resolvedType(constraint.expType)
    if (act == exp) {
      return nil
    }

    switch act.kind {

    case .free:
      return resolveFreeType(act, to: exp).and { (constraint, $0) }

    case .poly(let morphs):
      var match: Type? = nil
      for morph in morphs {
        if resolveSub(constraint, actType: morph, actDesc: "morph", expType: exp, expDesc: "expected type") != nil {
          continue // TODO: this is broken because we should be unwinding any resolved types.
        }
        if let prev = match { return (constraint, "multiple morphs match expected: \(prev); \(morph)") }
        match = morph
      }
      guard let morph = match else { return (constraint, "no morphs match expected") }
      if let existing = exprSubtypes[constraint.actForm] {
        return (constraint, "multiple subtype resolutions: \(existing); \(morph)")
      }
      exprSubtypes[constraint.actForm] = morph
      return nil

    default: break
    }

    switch exp.kind {

    case .all:
      return (constraint, "expected type of kind `All` not yet implemented")

    case .any(let members):
      if !members.contains(act) {
        return (constraint, "actual type is not a member of `Any` expected type")
      }

    case .cmpd(let expFields):
      return resolveConstraintToCmpd(constraint, act: act, exp: exp, expFields: expFields)

    case .free:
      return resolveType(exp, to: act).and { (constraint, $0) }

    case .host, .prim:
      return resolveConstraintToOpaque(constraint, act: act, exp: exp)

    case .poly:
      return (constraint, "expected `Poly` type is not implemented")

    case .prop(_, _):
      return (constraint, "prop constraints not implemented")

    case .sig(let expDom, let expRet):
      return resolveConstraintToSig(constraint, act: act, expDom: expDom, expRet: expRet)

    case .var_:
      return (constraint, "var constraints not implemented")
    }
    fatalError("unreachable.")
  }


  func resolveConstraintToCmpd(_ constraint: Constraint, act: Type, exp: Type, expFields: [TypeField]) -> (Constraint, String)? {

    switch act.kind {

    case .cmpd(let actFields):
      if expFields.count != actFields.count {
        let actFields = pluralize(actFields.count, "field")
        return (constraint, "actual struct type has \(actFields); expected \(expFields.count).")
        // TODO: should not be formatting potentially unused errors.
      }
      var needsConversion = false
      for (actField, expField) in zip(actFields, expFields) {
        switch resolveField(constraint, actField: actField, expField: expField) {
        case .ok: break
        case .convert: needsConversion = true
        case .failure(let failure): return failure
        }
      }
      if needsConversion {
        exprConversions[constraint.actForm] = Conversion(orig: act, conv: exp)
      }
      return nil

    default: return (constraint, "actual type is not a struct")
    }
  }

  enum FieldResolution {
    case ok
    case convert
    case failure((Constraint, String))
  }

  func resolveField(_ constraint: Constraint, actField: TypeField, expField: TypeField) -> FieldResolution {
    var res: FieldResolution = .ok
    if actField.label != nil {
      if actField.label != expField.label {
        return .failure((constraint, "struct field #\(actField.index) has \(actField.labelMsg); expected \(expField.labelMsg)"))
      }
    } else if expField.label != nil { // convert unlabeled to labeled.
      res = .convert
    }
    let index = actField.index
    if let failure = resolveSub(constraint,
      actType: actField.type, actDesc: "struct field \(index)",
      expType: expField.type, expDesc: "struct field \(index)") {
        return .failure(failure)
    }
    return res
  }

  func resolveConstraintToOpaque(_ constraint: Constraint, act: Type, exp: Type) -> (Constraint, String)? {
    switch act.kind {
    case .prop(let accessor, let accesseeType):
      switch accesseeType.kind {
      case .cmpd(let fields):
        for field in fields {
          if field.accessorString == accessor.accessorString {
            if let failure = resolveSub(constraint,
              actType: field.type, actDesc: "`\(field.accessorString)` property",
              expType: exp, expDesc: nil) {
                return failure
            }
            return nil
          }
        }
        return (constraint, "actual type has no field matching accessor") // TODO: this should be caught earlier.
      default: return (constraint, "actual type is not an accessible type")
      }
    default: return (constraint, "actual type is not expected opaque type")
    }
  }


  func resolveConstraintToSig(_ constraint: Constraint, act: Type, expDom: Type, expRet: Type) -> (Constraint, String)? {
    switch act.kind {

    case .sig(let actDom, let actRet):
      if let failure = resolveSub(constraint,
        actType: actDom, actDesc: "signature domain",
        expType: expDom, expDesc: "signature domain") {
          return failure
      }
      if let failure = resolveSub(constraint,
        actType: actRet, actDesc: "signature return",
        expType: expRet, expDesc: "signature return") {
          return failure
      }
      return nil

    default: return (constraint, "actual type is not a signature")
    }
  }


  func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String?, expType: Type, expDesc: String?) -> (Constraint, String)? {
    return resolveConstraint(constraint.subConstraint(
      actType: actType, actDesc: actDesc,
      expType: expType, expDesc: expDesc))
  }


  func resolve() {

    for constraint in constraints {
      if let (constraint, msg) = resolveConstraint(constraint) {
        let act = resolvedType(constraint.actType)
        let exp = resolvedType(constraint.expType)
        constraint.fail(act: act, exp: exp, msg: msg)
      }
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
        errL("freeIndicesToUnresolvedType: \(index): \(type)")
      }
    }
    check(freeIndicesToUnresolvedTypes.isEmpty)
    isResolved = true
  }
}
