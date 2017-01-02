// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


struct TypeCtx {

  typealias MsgThunk = ()->String

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
  private var freeUnifications: [Int:Type] = [:]
  private var exprOrigTypes = [Expr:Type]() // maps forms to original types.
  private var exprSubtypes = [Expr:Type]() // maps forms to legal, inferred compile time narrowing.
  private var exprConversions = [Expr:Conversion]() // maps forms to legal, inferred runtime conversions.

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()


  func assertIsTracking(_ expr: Expr) { assert(exprOrigTypes.contains(key: expr)) }

  private func origTypeFor(expr: Expr) -> Type { return exprOrigTypes[expr]! }

  private func subtypeFor(expr: Expr) -> Type? { return exprSubtypes[expr] }


  func typeFor(expr: Expr) -> Type {
    let type = subtypeFor(expr: expr).or(origTypeFor(expr: expr))
    return resolved(type: type)
  }


  func conversionFor(expr: Expr) -> Conversion? {
    return exprConversions[expr]
  }


  mutating func addFreeType() -> Type {
    let t = Type.Free(freeTypeCount)
    freeTypeCount += 1
    return t
  }


  mutating func trackExpr(_ expr: Expr, type: Type) {
    exprOrigTypes.insertNew(expr, value: type)
  }


  mutating func constrain(_ actExpr: Expr, expForm: Form? = nil, expType: Type, _ desc: String) {
    constraints.append(Constraint(
      actExpr: actExpr, expForm: expForm,
      actType: origTypeFor(expr: actExpr), actChain: .end,
      expType: expType, expChain: .end,
      desc: desc))
  }


  private func resolved(type: Type) -> Type {
    // TODO: need to track types to prevent/handle recursion.
    switch type.kind {
    case .all(let members):
      return Type.All(Set(members.map { self.resolved(type: $0) }))
    case .any(let members):
      return Type.Any_(Set(members.map { self.resolved(type: $0) }))
    case .cmpd(let fields):
      return Type.Cmpd(fields.map() { self.resolved(par: $0) })
    case .free(let freeIndex):
      return freeUnifications[freeIndex].or(type)
    case .host:
      return type
    case .poly(let members):
      return Type.Poly(Set(members.map { self.resolved(type: $0) }))
    case .prim:
      return type
    case .prop(let accessor, let type):
      return Type.Prop(accessor, type: resolved(type: type))
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    case .var_: return type
    }
  }

  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return (type == par.type) ? par : TypeField(label: par.label, type: type)
  }


  mutating func unify(freeType: Type, to type: Type) -> MsgThunk? {
    let freeIndex = freeType.freeIndex
    // TODO: determine whether always resolving to lower index is necessary.
    if case .free(let index) = type.kind {
      if freeIndex > index { // swap.
        assert(!freeUnifications.contains(key: index))
        freeUnifications[index] = freeType
        return nil
      }
    }
    assert(!freeUnifications.contains(key: freeIndex))
    freeUnifications[freeIndex] = type
    return nil
  }


  mutating func resolveConstraint(_ constraint: Constraint) -> Err? {
    let act = resolved(type: constraint.actType)
    let exp = resolved(type: constraint.expType)
    if (act == exp) {
      return nil
    }

    switch act.kind {

    case .free:
      return unify(freeType: act, to: exp).and { Err(constraint, msgThunk: $0) }

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
      if let existing = subtypeFor(expr: constraint.actExpr) {
        return Err(constraint, "multiple subtype resolutions: \(existing); \(morph)")
      }
      exprSubtypes[constraint.actExpr] = morph
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
      return unify(freeType: exp, to: act).and { Err(constraint, msgThunk: $0) }

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
      for (i, (actField, expField)) in zip(actFields, expFields).enumerated() {
        switch resolveField(constraint, actField: actField, expField: expField, index: i) {
        case .ok: break
        case .convert: needsConversion = true
        case .failure(let err): return err
        }
      }
      if needsConversion {
        exprConversions[constraint.actExpr] = Conversion(orig: act, conv: exp)
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

  mutating func resolveField(_ constraint: Constraint, actField: TypeField, expField: TypeField, index: Int) -> FieldResolution {
    var res: FieldResolution = .ok
    if actField.label != nil {
      if actField.label != expField.label {
        return .failure(Err(constraint, "struct field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)"))
      }
    } else if expField.label != nil { // convert unlabeled to labeled.
      res = .convert
    }
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
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) == accessor.accessorString {
            if let failure = resolveSub(constraint,
              actType: field.type, actDesc: "`\(field.accessorString(index: i))` property",
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
        let act = resolved(type: err.constraint.actType)
        let exp = resolved(type: err.constraint.expType)
        err.constraint.fail(act: act, exp: exp, msg: err.msgThunk())
      }
    }

    // check that resolution is complete.
    for expr in exprOrigTypes.keys {
      let type = typeFor(expr: expr)
      if type.frees.count > 0 {
        fatalError("unresolved frees in type: \(type)")
      }
    }
  }
}
