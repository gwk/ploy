// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  let globalCtx: GlobalCtx

  var constraints = [Constraint]()
  var constraintsResolved = [Bool]()
  var freeUnifications = [Type?]()
  var freeNevers = Set<Int>() // Never types are a special case, omitted from unification.

  var exprTypes = [Expr:Type]() // maps expressions to their types.
  var symRecords = [Sym:ScopeRecord]()
  var synths = [Expr:Expr]()
  var genSyms = [Sym]()

  var searchError: RelCon.Err? = nil

  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }


  mutating func addType(_ type: Type) -> Type {
    // Add a type to the system of constraints.
    if type.isConstraintEligible { return type }
    let idx = freeUnifications.count
    freeUnifications.append(type)
    return Type.Free(idx)
  }


  mutating func addFreeType() -> Type {
    let idx = freeUnifications.count
    freeUnifications.append(nil)
    return Type.Free(idx)
  }


  mutating func addConstraint(_ constraint: Constraint) {
    constraints.append(constraint)
    constraintsResolved.append(false)
  }


  func typeFor(expr: Expr) -> Type {
    guard let type = exprTypes[expr] else { expr.form.fatal("untracked expression") }
    return resolved(type: type)
  }


  func resolved(type: Type) -> Type {
    // TODO: need to track types to prevent/handle recursion?
    if type.isResolved { return type }
    switch type.kind {
    case .all(let members):
      return Type.All(Set(members.map { self.resolved(type: $0) }))
    case .any(let members):
      return Type.Any_(Set(members.map { self.resolved(type: $0) }))
    case .struct_(let fields, let variants):
      return Type.Struct(
        fields: fields.map() { self.resolved(par: $0) },
        variants: variants.map() { self.resolved(par: $0) })
    case .free(let freeIndex):
      if let substitution = freeUnifications[freeIndex] {
        return resolved(type: substitution)
      } else { return type }
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    case .variantMember(let variant):
      return Type.VariantMember(variant: resolved(par: variant))
    default: fatalError("type kind cannot contain frees: \(type)")
    }
  }


  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return TypeField(isVariant: par.isVariant, label: par.label, type: type)
  }


  mutating func unify(freeIndex: Int, to type: Type) {
    assert(type.isConstraintEligible)
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
    let accessor = prop.acc.accessor

    switch accesseeType.kind {
    case .struct_(let fields, let variants):
      if case .untag(let tag) = accessor {
        let name = tag.sym.name
        for variant in variants {
          if variant.label! == name {
            try resolveSub(constraint: .rel(RelCon(
              act: Side(expr: .acc(prop.acc), type: variant.type),
              exp: Side(expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
              desc: "variant")))
            return true
          }
        }
        throw prop.error("accessee has no variant named `\(name)`")
      } else {
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) == accessor.accessorString {
            try resolveSub(constraint: .rel(RelCon(
              act: Side(expr: .acc(prop.acc), type: field.type),
              exp: Side(expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
              desc: "access")))
            return true
          }
        }
        // TODO: variant access? would return Opt.
        throw prop.error("accessee has no field matching accessor `\(accessor.accessorString)`")
      }
    default: throw prop.error("accessee is not a struct")
    }
  }


  mutating func resolve(rel: RelCon) throws -> Bool {
    // Return value indicates whether the constraint was resolved;
    // returning false allows the solver to defer solving a constraint until additional free variables have been unified.

    let act = resolved(type: rel.act.type)
    let exp = resolved(type: rel.exp.type)

    if (act == exp) { return true }

    switch (act.kind, exp.kind) {

    case (.poly, .free): // cannot unify an actual polymorph because it prevents polymorph selection; defer instead.
      return false

    case (.poly(let morphs), _): // actual polymorph; attempt to select a morph.
      var match: (TypeCtx, Type)? = nil
      for morph in morphs {
        assert(morph.isResolved)
        var ctx = self // copy ctx.
        do {
          try ctx.resolveSub(rel, actType: morph, actDesc: "morph")
        } catch {
          continue
        }
        if let (_, prev) = match {
          searchError = rel.error("multiple morphs match expected: \(prev); \(morph)")
          return false
        }
        match = (ctx, morph)
      }
      guard let (ctx, _) = match else { throw rel.error("no morphs match expected") }
      self = ctx
      searchError = nil
      return true

    case (.free(let ia), .free(let ie)):
      // TODO: determine whether always resolving to lower index is necessary.
      if ia > ie { unify(freeIndex: ia, to: exp); return true }
      else       { unify(freeIndex: ie, to: act); return true }

    case (.free(let ia), _):
      // note: if expected is Never we do unify; the caller expects to never return.
      unify(freeIndex: ia, to: addType(exp));
      return true

    case (_, .free(let ie)):
      if act == typeNever {
        // if actual is Never, do not unify; other code paths may return, and we want that type to bind to the free exp.
        // however this might be the only branch, so we need to remember this and fall back if exp remains free.
        freeNevers.insert(ie)
      } else {
        unify(freeIndex: ie, to: addType(act))
      }
      return true

    case (_, .any(let members)):
      if !members.contains(act) {
        throw rel.error("actual type is not a member of `Any` expected type")
      }
      return true

    case (.prim, _) where act == typeNever: // never is compatible with any expected type.
      return true

    case (.sig(let actDR), .sig(let expDR)):
      return try resolveSigToSig(rel, act: actDR, exp: expDR)

    case (.struct_(let actFV), .struct_(let expFV)):
      if exp == typeNull {
        throw rel.error("implicit struct conversion to nil is disallowed")
      }
      return try resolveStructToStruct(rel, act: actFV, exp: expFV)

    case (.struct_(_, let actVariants), .variantMember(let expVariant)):
      return try resolveStructToVariantMember(rel, actVariants: actVariants, expVariant: expVariant)

    default: throw rel.error("actual type is not expected type")
    }
  }


  mutating func resolveSigToSig(_ rel: RelCon, act: (dom: Type, ret: Type), exp: (dom: Type, ret: Type)) throws -> Bool {
    try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigDom, actType: addType(act.dom), actDesc: "signature domain",
      expExpr: rel.exp.litExpr?.sigDom, expType: addType(exp.dom), expDesc: "signature domain")
    try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigRet, actType: addType(act.ret), actDesc: "signature return",
      expExpr: rel.exp.litExpr?.sigRet, expType: addType(exp.ret), expDesc: "signature return")
    return true
  }


  mutating func resolveStructToStruct(_ rel: RelCon,
   act: (fields: [TypeField], variants: [TypeField]),
   exp: (fields: [TypeField], variants: [TypeField])) throws -> Bool {
    if exp.fields.count != act.fields.count {
      let nFields = pluralize(act.fields.count, "field")
      throw rel.error("actual struct has \(nFields); expected \(exp.fields.count)")
    }
    let litActFields = rel.act.litExpr?.parenFieldEls
    let litExpFields = rel.exp.litExpr?.parenFieldEls
    for (index, (actField, expField)) in zip(act.fields, exp.fields).enumerated() {
      if actField.label != nil && actField.label != expField.label {
        throw rel.error("field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)")
      }
      try resolveSub(rel,
        actExpr: litActFields?[index], actType: actField.type, actDesc: "field \(index)",
        expExpr: litExpFields?[index], expType: expField.type, expDesc: "field \(index)")
    }
    actual: for (actIdx, actVariant) in act.variants.enumerated() {
      let litActVariants = rel.act.litExpr?.parenVariantEls
      for (expIdx, expVariant) in exp.variants.enumerated() { // TODO: fix quadratic behavior.
        if expVariant.label == actVariant.label {
          let litExpVariants = rel.exp.litExpr?.parenVariantEls
          try resolveSub(rel,
            actExpr: litActVariants?[actIdx], actType: actVariant.type, actDesc: "variant \(actIdx)",
            expExpr: litExpVariants?[expIdx], expType: expVariant.type, expDesc: "variant \(expIdx)")
            continue actual
        }
      }
      throw rel.error("actual variant tag not found in expected variants: `-\(actVariant.label!)`")
    }
    return true
  }


  mutating func resolveStructToVariantMember(_ rel: RelCon, actVariants: [TypeField], expVariant: TypeField) throws -> Bool {
    for actVariant in actVariants {
      if actVariant.label == expVariant.label {
        try resolveSub(rel,
          actExpr: nil, actType: actVariant.type, actDesc: "variant",
          expExpr: nil, expType: expVariant.type, expDesc: "variant")
      return true
      }
    }
    throw rel.error("actual variants do not contain expected variant label: `-\(expVariant.label!)`")
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
      while i < constraints.count { // use while loop because constraints array may grow during iteration.
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
          } // else deferred to next round.
        } catch let err as RelCon.Err {
          error(err)
        } catch let err as PropCon.Err {
          error(err)
        } catch { fatalError() }
      }
      assert(doneThisRound >= doneCount)
      if doneThisRound == doneCount {
        if let searchError = searchError { error(searchError) }
        // If we do not have a specific error from polymorph search, just show generic error for first constraint.
        for (c, isResolved) in zip(constraints, constraintsResolved) {
          if isResolved { continue }
          switch c {
          case .prop(let prop): error(prop.error("cannot resolve constraint"))
          case .rel(let rel): error(rel.error("cannot resolve constraint"))
          }
        }
        fatalError("resolve loop did not progress") // should be unreachable.
      }
      doneCount = doneThisRound
    }

    // fill in frees that were only bound to Never.
    for idx in freeNevers {
      if freeUnifications[idx] == nil {
        freeUnifications[idx] = typeNever
      }
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
    let actDesc = r.act.chain.map({"\($0) -> "}).joined()
    let expDesc = r.exp.chain.map({"\($0) -> "}).joined()
    if r.act.expr != r.exp.expr {
      r.act.expr.form.failType("\(r.desc) \(msg). \(actDesc)actual type: \(act)",
        notes: (r.exp.expr.form, "\(expDesc)expected type: \(exp)"))
    } else {
      r.act.expr.form.failType("\(r.desc) \(msg).\n  \(actDesc)actual type:   \(act);\n  \(expDesc)expected type: \(exp).")
    }
  }

  func describeState(_ label: String = "", showConstraints: Bool = false, showUnifications: Bool = true) {
    errL("TypeCtx.describeState: \(label)")
    if showConstraints {
      errL("Constraints:")
      for (constraint, isResolved) in zip(constraints, constraintsResolved) {
        errL("  \(isResolved ? "+" : "-") \(constraint)")
      }
    }
    if showUnifications {
      errL("Unifications:")
      for (i, origType) in freeUnifications.enumerated() {
        if let origType = origType {
          let type = resolved(type: origType)
          let never = freeNevers.contains(i) ? " (Never)" : ""
          let frees = type.childFrees.isEmpty ? "" : " : \(type.childFrees.sorted())"
          errL("  \(i): \(type)\(never)\(frees)")
        } else {
          errL("  \(i): nil")
        }
      }
    }
    errN()
  }
}
