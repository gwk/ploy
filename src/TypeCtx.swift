// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


struct TypeCtx {

  typealias MsgThunk = () ->String

  struct Err: Error {
    let constraint: Constraint
    let msgThunk: MsgThunk

    init(_ constraint: Constraint, msgThunk: @escaping MsgThunk) {
      self.constraint = constraint
      self.msgThunk = msgThunk
    }

    init(_ constraint: Constraint, _ msgThunk: @escaping @autoclosure ()->String) {
      self.constraint = constraint
      self.msgThunk = msgThunk
    }
  }

  private var constraints: [Constraint] = []
  private var freeTypeCount = 0
  private var resolvedTypes: [Type:Type] = [:] // maps all types containing free types to partially or completely resolved types.
  private var freeIndicesToUnresolvedTypes: DictOfSet<Int, Type> = [:] // maps free types to all types containing them.
  private var exprOriginalTypes = [Form:Type]() // maps forms to original types.
  private var exprSubtypes = [Form:Type]() // maps forms to legal, inferred compile time narrowing.
  private var exprConversions = [Form:Conversion]() // maps forms to legal, inferred runtime conversions.

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()


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


  mutating func addFreeType() -> Type {
    let t = Type.Free(freeTypeCount)
    freeTypeCount += 1
    return t
  }


  mutating func trackExpr(_ expr: Expr, type: Type) {
    exprOriginalTypes.insertNew(expr.form, value: type)
    trackFreeTypes(type)
  }


  mutating func trackFreeTypes(_ type: Type) {
    for free in type.frees {
      guard case .free(let index) = free.kind else { fatalError() }
      freeIndicesToUnresolvedTypes.insert(index, member: type)
    }
  }


  mutating func constrain(_ actExpr: Expr, expForm: Form? = nil, expType: Type, _ desc: String) {
    trackFreeTypes(expType)
    constraints.append(Constraint(
      form: actExpr.form, expForm: expForm,
      actType: originalTypeForExpr(actExpr), actChain: .end,
      expType: expType, expChain: .end,
      desc: desc))
  }


  mutating func constrain(form: Form, type: Type, expForm: Form? = nil, expType: Type, _ desc: String) {
    trackFreeTypes(expType)
    constraints.append(Constraint(
      form: form, expForm: expForm,
      actType: type, actChain: .end,
      expType: expType, expChain: .end,
      desc: desc))
  }


  mutating func resolveType(_ type: Type, to resolved: Type) -> MsgThunk? {
    if let existing = resolvedTypes[type] {
      return {"multiple resolutions not yet supported;\n  original: \(type)\n  existing: \(existing)\n  incoming: \(resolved)"}
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


  mutating func resolveFreeType(_ freeType: Type, to resolved: Type) -> MsgThunk? {
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


  mutating func resolveConstraint(_ constraint: Constraint) -> Err? {
    let act = resolvedType(constraint.actType)
    let exp = resolvedType(constraint.expType)
    if (act == exp) {
      return nil
    }

    switch act.kind {

    case .free:
      return resolveFreeType(act, to: exp).and { Err(constraint, msgThunk: $0) }

    case .poly(let morphs):
      var match: Type? = nil
      for morph in morphs {
        if resolveSub(constraint, actType: morph, actDesc: "morph", expType: exp, expDesc: "expected type") != nil {
          continue // TODO: this is broken because we should be unwinding any resolved types.
        }
        if let prev = match { return Err(constraint, "multiple morphs match expected: \(prev); \(morph)") }
        match = morph
      }
      guard let morph = match else { return Err(constraint, "no morphs match expected") }
      if let existing = exprSubtypes[constraint.form] {
        return Err(constraint, "multiple subtype resolutions: \(existing); \(morph)")
      }
      exprSubtypes[constraint.form] = morph
      return nil

    default: break
    }

    switch exp.kind {

    case .all:
      return Err(constraint, "expected type of kind `All` not yet implemented")

    case .any(let members):
      if !members.contains(act) {
        return Err(constraint, "actual type is not a member of `Any` expected type")
      }

    case .cmpd(let expFields):
      return resolveConstraintToCmpd(constraint, act: act, exp: exp, expFields: expFields)

    case .free:
      return resolveType(exp, to: act).and { Err(constraint, msgThunk: $0) }

    case .host, .prim:
      return resolveConstraintToOpaque(constraint, act: act, exp: exp)

    case .poly:
      return Err(constraint, "expected `Poly` type is not implemented")

    case .prop(_, _):
      return Err(constraint, "prop constraints not implemented")

    case .sig(let expDom, let expRet):
      return resolveConstraintToSig(constraint, act: act, expDom: expDom, expRet: expRet)

    case .var_:
      return Err(constraint, "var constraints not implemented")
    }
    fatalError("unreachable.")
  }


  mutating func resolveConstraintToCmpd(_ constraint: Constraint, act: Type, exp: Type, expFields: [TypeField]) -> Err? {

    switch act.kind {

    case .cmpd(let actFields):
      if expFields.count != actFields.count {
        let actFields = pluralize(actFields.count, "field")
        return Err(constraint, "actual struct type has \(actFields); expected \(expFields.count)")
      }
      var needsConversion = false
      for (actField, expField) in zip(actFields, expFields) {
        switch resolveField(constraint, actField: actField, expField: expField) {
        case .ok: break
        case .convert: needsConversion = true
        case .failure(let err): return err
        }
      }
      if needsConversion {
        exprConversions[constraint.form] = Conversion(orig: act, conv: exp)
      }
      return nil

    default: return Err(constraint, "actual type is not a struct")
    }
  }

  enum FieldResolution {
    case ok
    case convert
    case failure(Err)
  }

  mutating func resolveField(_ constraint: Constraint, actField: TypeField, expField: TypeField) -> FieldResolution {
    var res: FieldResolution = .ok
    if actField.label != nil {
      if actField.label != expField.label {
        return .failure(Err(constraint, "struct field #\(actField.index) has \(actField.labelMsg); expected \(expField.labelMsg)"))
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

  mutating func resolveConstraintToOpaque(_ constraint: Constraint, act: Type, exp: Type) -> Err? {
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
        return Err(constraint, "actual type has no field matching accessor") // TODO: this should be caught earlier.
      default: return Err(constraint, "actual type is not an accessible type")
      }
    default: return Err(constraint, "actual type is not expected opaque type")
    }
  }


  mutating func resolveConstraintToSig(_ constraint: Constraint, act: Type, expDom: Type, expRet: Type) -> Err? {
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

    default: return Err(constraint, "actual type is not a signature")
    }
  }


  mutating func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String?, expType: Type, expDesc: String?) -> Err? {
    return resolveConstraint(constraint.subConstraint(
      actType: actType, actDesc: actDesc,
      expType: expType, expDesc: expDesc))
  }


  mutating func resolve() {

    for constraint in constraints {
      if let err = resolveConstraint(constraint) {
        let act = resolvedType(err.constraint.actType)
        let exp = resolvedType(err.constraint.expType)
        err.constraint.fail(act: act, exp: exp, msg: err.msgThunk())
      }
    }

    // check that resolution is complete.
    for i in 0..<freeTypeCount {
      let type = Type.Free(i)
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
  }
}
