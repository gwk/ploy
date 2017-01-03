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
      actExpr: actExpr,
      expForm: expForm,
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
      let accesseeType = resolved(type: type)
      switch accesseeType.kind {
      case .cmpd(let fields):
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) == accessor.accessorString {
            return field.type
          }
        }
        fallthrough
      default:  return Type.Prop(accessor, type: accesseeType)
      }
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    case .var_: return type
    }
  }


  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return (type == par.type) ? par : TypeField(label: par.label, type: type)
  }


  mutating func unify(freeIndex: Int, to type: Type) -> MsgThunk? {
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

    switch (act.kind, exp.kind) {

    case (.free(let ia), .free(let ie)):
      // TODO: determine whether always resolving to lower index is necessary.
      if ia > ie { return unify(freeIndex: ie, to: act).and { Err(constraint, msgThunk: $0) }
      } else {     return unify(freeIndex: ia, to: exp).and { Err(constraint, msgThunk: $0) } }

    case (.free(let ia), _): return unify(freeIndex: ia, to: exp).and { Err(constraint, msgThunk: $0) }
    case (_, .free(let ie)): return unify(freeIndex: ie, to: act).and { Err(constraint, msgThunk: $0) }

    case (.poly(let morphs), _):
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

    case (.prop(let accessor, let accesseeType), _):
      let accType = resolved(type: accesseeType)
      switch accType.kind {
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
        return Err(constraint, "actual type has no field matching accessor")
      default: return Err(constraint, "actual type is not an accessible type")
      }

    case (_, .any(let members)):
      if !members.contains(act) {
        return Err(constraint, "actual type is not a member of `Any` expected type")
      }
      return nil

    case (_, .cmpd(let expFields)):
      return resolveConstraintToCmpd(constraint, act: act, exp: exp, expFields: expFields)

    case (_, .sig(let expDom, let expRet)):
      return resolveConstraintToSig(constraint, act: act, expDom: expDom, expRet: expRet)

    default: return Err(constraint, "actual type is not expected type")
    }
  }


  mutating func resolveConstraintToCmpd(_ constraint: Constraint, act: Type, exp: Type, expFields: [TypeField]) -> Err? {

    switch act.kind {

    case .cmpd(let actFields):
      if expFields.count != actFields.count {
        let actFields = pluralize(actFields.count, "field")
        return Err(constraint, "actual struct type has \(actFields); expected \(expFields.count)")
      }
      var needsConversion = false
      let lexFields = constraint.actExpr.cmpdFields
      for (i, (actField, expField)) in zip(actFields, expFields).enumerated() {
        switch resolveField(constraint, actField: actField, expField: expField, lexField: lexFields?[i], index: i) {
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

  mutating func resolveField(_ constraint: Constraint, actField: TypeField, expField: TypeField, lexField: Expr?, index: Int) -> FieldResolution {
    var res: FieldResolution = .ok
    if actField.label != nil {
      if actField.label != expField.label {
        return .failure(Err(constraint, "struct field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)"))
      }
    } else if expField.label != nil { // convert unlabeled to labeled.
      res = .convert
    }
    // TODO: if let lexField = lexField...
    if let failure = resolveSub(constraint,
      actType: actField.type, actDesc: "struct field \(index)",
      expType: expField.type, expDesc: "struct field \(index)") {
        return .failure(failure)
    }
    return res
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
    let sub = Constraint(
      actExpr: constraint.actExpr,
      expForm: constraint.expForm,
      actType: actType, actChain: constraint.actChain.prepend(opt: actDesc),
      expType: expType, expChain: constraint.expChain.prepend(opt: expDesc),
      desc: constraint.desc)
    return resolveConstraint(sub)
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
