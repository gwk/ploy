// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  let globalCtx: GlobalCtx

  var constraints = [Constraint]()
  var constraintsResolved = [Bool]()

  // only mutated during generation phase.
  var exprTypes = [Expr:Type]() // maps expressions to their types.
  var symRecords = [Sym:ScopeRecord]()
  var freeTypeCount = 0

  // mutated during resolution phase.
  var freeUnifications = [Int:Type]()


  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }


  func typeFor(expr: Expr) -> Type {
    return resolved(type: exprTypes[expr]!)
  }


  func resolved(type: Type) -> Type {
    // TODO: need to track types to prevent/handle recursion?
    if type.isResolved { return type }
    switch type.kind {
    case .all(let members):
      return Type.All(Set(members.map { self.resolved(type: $0) }))
    case .any(let members):
      return Type.Any_(Set(members.map { self.resolved(type: $0) }))
    case .cmpd(let fields):
      return Type.Cmpd(fields.map() { self.resolved(par: $0) })
    case .free(let freeIndex):
      if let substitution = freeUnifications[freeIndex] {
        return resolved(type: substitution)
      } else { return type }
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    default: fatalError("type kind cannot contain frees: \(type)")
    }
  }


  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return (type == par.type) ? par : TypeField(label: par.label, type: type)
  }


  mutating func unify(freeIndex: Int, to type: Type) {
    assert(!freeUnifications.contains(key: freeIndex))
    freeUnifications[freeIndex] = type
  }


  mutating func resolve(_ constraint: Constraint) throws -> Bool {
    switch constraint {
    case .prop(let prop): return try resolve(prop: prop)
    case .rel(let rel): return try resolve(rel: rel)
    }
  }


  mutating func resolve(prop: PropCon) throws -> Bool {
    let accesseeType = resolved(type: prop.accesseeType)
    let accType = resolved(type: prop.accType)
    switch accesseeType.kind {
    case .cmpd(let fields):
      for (i, field) in fields.enumerated() {
        if field.accessorString(index: i) == prop.acc.accessor.propAccessor.accessorString {
          try resolveSub(constraint: .rel(RelCon(
            act: Side(expr: .acc(prop.acc), type: field.type),
            exp: Side(expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
            desc: "access")))
          return true
        }
      }
      throw prop.error("accessee has no field matching accessor")
    default: throw prop.error("accessee is not a struct")
    }
  }


  mutating func resolve(rel: RelCon) throws -> Bool {
    let act = resolved(type: rel.act.type)
    let exp = resolved(type: rel.exp.type)

    if (act == exp) { return true }

    switch (act.kind, exp.kind) {

    case (.poly, .free):
      return false

    // TODO: handle cases where sig or compound contains frees and must be deferred.

    case (.poly(let morphs), _):
      var match: (TypeCtx, Type)? = nil
      for morph in morphs {
        var ctx = self // copy ctx.
        do {
          try ctx.resolveSub(rel, actType: morph, actDesc: "morph")
        } catch {
          continue
        }
        if let (_, prev) = match { throw rel.error("multiple morphs match expected: \(prev); \(morph)") }
        match = (ctx, morph)
      }
      guard let (ctx, _) = match else { throw rel.error("no morphs match expected") }
      self = ctx
      return true

    case (.free(let ia), .free(let ie)):
      // TODO: determine whether always resolving to lower index is necessary.
      if ia > ie { unify(freeIndex: ia, to: exp); return true }
      else {       unify(freeIndex: ie, to: act); return true }

    case (.free(let ia), _): unify(freeIndex: ia, to: exp); return true
    case (_, .free(let ie)): unify(freeIndex: ie, to: act); return true

    case (_, .any(let members)):
      if !members.contains(act) {
        throw rel.error("actual type is not a member of `Any` expected type")
      }
      return true

    case (.cmpd(let actFields), .cmpd(let expFields)):
      return try resolveCmpdToCmpd(rel, act: act, actFields: actFields, expFields: expFields)

    case (.sig(let actDom, let actRet), .sig(let expDom, let expRet)):
      return try resolveSigToSig(rel, actDom: actDom, actRet: actRet, expDom: expDom, expRet: expRet)

    default: throw rel.error("actual type is not expected type")
    }
  }


  mutating func resolveCmpdToCmpd(_ rel: RelCon, act: Type, actFields: [TypeField], expFields: [TypeField]) throws -> Bool {
    if expFields.count != actFields.count {
      let nFields = pluralize(actFields.count, "field")
      throw rel.error("actual struct has \(nFields); expected \(expFields.count)")
    }
    let litActFields = rel.act.litExpr?.cmpdFields
    let litExpFields = rel.exp.litExpr?.cmpdFields
    for (index, (actField, expField)) in zip(actFields, expFields).enumerated() {
      if actField.label != nil && actField.label != expField.label {
        throw rel.error("field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)")
      }
      try resolveSub(rel,
        actExpr: litActFields?[index], actType: actField.type, actDesc: "field \(index)",
        expExpr: litExpFields?[index], expType: expField.type, expDesc: "field \(index)")
    }
    return true
  }


  mutating func resolveSigToSig(_ rel: RelCon, actDom: Type, actRet: Type, expDom: Type, expRet: Type) throws -> Bool {
    try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigDom, actType: actDom, actDesc: "signature domain",
      expExpr: rel.exp.litExpr?.sigDom, expType: expDom, expDesc: "signature domain")
    try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigRet, actType: actRet, actDesc: "signature return",
      expExpr: rel.exp.litExpr?.sigRet, expType: expRet, expDesc: "signature return")
    return true
  }


  mutating func resolveSub(constraint: Constraint) throws {
    let done = try resolve(constraint)
    if !done {
      addConstraint(constraint)
    }
  }


  mutating func resolveSub(_ rel: RelCon,
   actExpr: Expr?, actType: Type, actDesc: String,
   expExpr: Expr?, expType: Type, expDesc: String) throws {
    try resolveSub(constraint: Constraint.rel(RelCon(
      act: rel.act.sub(expr: actExpr, type: actType, desc: actDesc),
      exp: rel.exp.sub(expr: expExpr, type: expType, desc: expDesc),
      desc: rel.desc)))
  }


  mutating func resolveSub(_ rel: RelCon, actType: Type, actDesc: String) throws {
    try resolveSub(constraint: Constraint.rel(RelCon(
      act: Side(expr: rel.act.expr, type: actType, chain: .link(actDesc, rel.act.chain)),
      exp: rel.exp,
      desc: rel.desc)))
  }


  mutating func resolveAll() {
    var doneCount = 0
    while doneCount < constraints.count {
      var i = 0
      var doneThisRound = 0
      while i < constraints.count {
        let index = i
        i += 1
        if constraintsResolved[index] {
          doneThisRound += 1
          continue
        }
        let constraint = constraints[index]
        do {
          let done = try resolve(constraint)
          if done {
            constraintsResolved[index] = true
            doneThisRound += 1
          }
        } catch let err as RelCon.Err {
          error(err)
        } catch let err as PropCon.Err {
          error(err)
        } catch { fatalError() }
      }
      assert(doneThisRound >= doneCount)
      if doneThisRound == doneCount {
        fatalError("resolve loop did not progress.") // TODO: error reporting.
      }
      doneCount = doneThisRound
    }

    // check that resolution is complete.
    for expr in exprTypes.keys {
      let type = typeFor(expr: expr)
      if type.frees.count > 0 {
        fatalError("unresolved frees in type: \(type)")
      }
    }
  }


  func error(_ err: PropCon.Err) -> Never {
    let accesseeType = resolved(type: err.prop.accesseeType)
    err.prop.acc.accessee.form.failType("\(err.msg). accessee type: \(accesseeType)",
      notes: (err.prop.acc.accessor.form, "accessor is here."))
  }


  func error(_ err: RelCon.Err) -> Never {
    let r = err.rel
    let msg = err.msgThunk()
    let act = resolved(type: r.act.type)
    let exp = resolved(type: r.exp.type)
    let actDesc = r.act.chain.map({"\($0) -> "}).join()
    let expDesc = r.exp.chain.map({"\($0) -> "}).join()

    if r.act.expr != r.exp.expr {
      r.act.expr.form.failType("\(r.desc) \(msg). \(actDesc)actual type: \(act)",
        notes: (r.exp.expr.form, "\(expDesc)expected type: \(exp)"))
    } else {
      r.act.expr.form.failType("\(r.desc) \(msg).\n  \(actDesc)actual type:   \(act);\n  \(expDesc)expected type: \(exp).")
    }
  }
}
