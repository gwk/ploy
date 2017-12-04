// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  var constraints = [Constraint]()
  var freeUnifications = [Type?]()
  var freeParents: [Int] = [] // Map free indices to parent context.
  var freeNevers = Set<Int>() // Never types are a special case, omitted from unification.

  var searchError: RelCon.Err? = nil


  mutating func addFreeType() -> Type {
    let idx = freeUnifications.count
    freeUnifications.append(nil)
    return Type.Free(idx)
  }


  mutating func addConstraint(_ constraint: Constraint) {
    constraints.append(constraint)
  }


  func resolved(type: Type) -> Type {
    // TODO: need to track types to prevent/handle recursion?
    if type.isResolved { return type }
    switch type.kind {
    case .all(let members):
      return try! Type.All(members.map { self.resolved(type: $0) })
    case .any(let members):
      return try! Type.Any_(members.map { self.resolved(type: $0) })
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
              act: Side(.act, expr: .acc(prop.acc), type: variant.type),
              exp: Side(.exp, expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
              desc: "variant")))
            return true
          }
        }
        throw prop.error("accessee has no variant named `\(name)`")
      } else {
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) == accessor.accessorString {
            try resolveSub(constraint: .rel(RelCon(
              act: Side(.act, expr: .acc(prop.acc), type: field.type),
              exp: Side(.exp, expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
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

    case (.poly, _): // actual polymorph; attempt to select a morph.
      return try resolvePoly(rel, act: act, exp: exp)

    case (.free(let ia), .free):
      // Propagate the actual type as far as possible. TODO: figure out if this matters.
      unify(freeIndex: ia, to: exp)
      return true

    case (.free(let ia), _):
      // If expected is Never then unify; the caller expects to never return.
      unify(freeIndex: ia, to: exp);
      return true

    case (_, .free(let ie)):
      if act == typeNever {
        // If actual is Never, then do not unify; other code paths may return, and we want that type to bind to the free exp.
        // However this might be the only branch, so we need to remember the Never and fall back to it if exp remains free.
        freeNevers.insert(ie)
      } else {
        unify(freeIndex: ie, to: act)
      }
      return true

    case (.any(let actMembers), .any(let expMembers)):
      for actMember in actMembers {
        if !expMembers.contains(actMember) {
          throw rel.error({"\($0) `Any` type is not subset of `Any` \($1) type; outstanding member: `\(actMember)`"})
        }
      }
      return true

    case (_, .any(let members)):
      if !members.contains(act) {
        throw rel.error({"\($0) type is not a member of `Any` \($1) type"})
      }
      return true

    case (.prim, _) where act == typeNever: // never is compatible with any expected type.
      return true

    case (.sig(let actDR), .sig(let expDR)):
      return try resolveSigToSig(rel, act: actDR, exp: expDR)

    case (.struct_(let actFV), .struct_(let expFV)):
      if exp == typeNull {
        throw rel.error({(_, _) in "implicit struct conversion to nil is disallowed"})
      }
      return try resolveStructToStruct(rel, act: actFV, exp: expFV)

    case (.struct_(_, let actVariants), .variantMember(let expVariant)):
      return try resolveStructToVariantMember(rel, actVariants: actVariants, expVariant: expVariant)

    default: throw rel.error({"\($0) type is not \($1) type"})
    }
  }


  mutating func resolvePoly(_ rel: RelCon, act: Type, exp: Type) throws -> Bool {
    guard case .poly(let morphs) = act.kind else { fatalError() }
    assert(exp.vars.isEmpty)
    let (subCtx, subExp) = subCtxAndType(parentType: exp)
    var matchMorph: Type? = nil
    var matchCtx = TypeCtx() // overwritten by matching iteration.
    for morph in morphs {
      assert(morph.isResolved)
      assert(morph.vars.isEmpty) // TODO: support generic implementations in extensibles.
      var childCtx = subCtx // copy.
      childCtx.addConstraint(.rel(RelCon(
        act: Side(.act, expr: rel.act.expr, type: morph, chain: .link("morph", rel.act.chain)),
        exp: Side(.exp, expr: rel.exp.expr, type: subExp, chain: rel.exp.chain),
        desc: rel.desc)))
      do { try childCtx.resolveAll() }
      catch { continue }
      if let prev = matchMorph {
        if searchError == nil { // can have multiple search errors; keep the first one.
          searchError = rel.error({"multiple morphs of \($0) match \($1): \(prev), \(morph)"})
        }
        return false
      }
      matchMorph = morph
      matchCtx = childCtx
    }
    if case .any(let unionMembers) = exp.kind, matchMorph == nil { // expected type is dynamic.
      fatalError("polymorphic union matching unimplemented: \(unionMembers)")
    }
    if matchMorph == nil { throw rel.error({"no morphs of \($0) match \($1)"}) }
    mergeSubCtx(matchCtx)
    return true
  }


  mutating func resolveSigToSig(_ rel: RelCon, act: (dom: Type, ret: Type), exp: (dom: Type, ret: Type)) throws -> Bool {
    try resolveSub(rel, // domain is contravariant.
      actRole: .act, actExpr: rel.exp.litExpr?.sigDom, actType: exp.dom, actDesc: "signature domain", // note reversal.
      expRole: .dom, expExpr: rel.act.litExpr?.sigDom, expType: act.dom, expDesc: "signature domain") // note reversal.
    try resolveSub(rel, // return is covariant.
      actExpr: rel.act.litExpr?.sigRet, actType: act.ret, actDesc: "signature return",
      expExpr: rel.exp.litExpr?.sigRet, expType: exp.ret, expDesc: "signature return")
    return true
  }


  mutating func resolveStructToStruct(_ rel: RelCon,
   act: (fields: [TypeField], variants: [TypeField]),
   exp: (fields: [TypeField], variants: [TypeField])) throws -> Bool {
    if exp.fields.count != act.fields.count {
      let nFields = pluralize(act.fields.count, "field")
      throw rel.error({"\($0) struct has \(nFields); \($1) struct has \(exp.fields.count)"})
    }
    let litActFields = rel.act.litExpr?.parenFieldEls
    let litExpFields = rel.exp.litExpr?.parenFieldEls
    for (index, (actField, expField)) in zip(act.fields, exp.fields).enumerated() {
      if actField.label != nil && actField.label != expField.label {
        throw rel.error({"\($0) field #\(index) has \(actField.labelMsg); \($1) field has \(expField.labelMsg)"})
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
      throw rel.error({"\($0) variant tag not found in \($1) variants: `-\(actVariant.label!)`"})
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
    throw rel.error({"\($0) variants do not contain \($1) variant label: `-\(expVariant.label!)`"})
  }


  mutating func resolveSub(constraint: Constraint) throws {
    let done = try resolve(constraint)
    if !done {
      addConstraint(constraint)
    }
  }


  mutating func resolveSub(_ rel: RelCon,
   actRole: Side.Role = .act, actExpr: Expr? = nil, actType: Type, actDesc: String,
   expRole: Side.Role = .exp, expExpr: Expr? = nil, expType: Type, expDesc: String) throws {
    try resolveSub(constraint: .rel(RelCon(
      act: rel.act.sub(.act, expr: actExpr, type: actType, desc: actDesc),
      exp: rel.exp.sub(.exp, expr: expExpr, type: expType, desc: expDesc),
      desc: rel.desc)))
  }


  mutating func copy(parentType: Type) -> Type {
    return parentType.transformLeaves { type in
      switch type.kind {
      case .free(let index):
        assert(self.freeUnifications.count == self.freeParents.count)
        // Note: the counts match because we are creating a new child ctx.
        // Once resolution begins, addType can cause freeUnifications to grow.
        self.freeParents.append(index)
        return self.addFreeType()
      default: return type
      }
    }
  }


  func copyForParent(type: Type) -> Type {
    return type.transformLeaves { type in
      switch type.kind {
      case .free(let index): return .Free(self.freeParents[index])
      default: return type
      }
    }
  }


  func subCtxAndType(parentType: Type) -> (TypeCtx, Type) {
    var subCtx = TypeCtx()
    let childType = subCtx.copy(parentType: parentType)
    return (subCtx, childType)
  }


  mutating func mergeSubCtx(_ ctx: TypeCtx) {
    assert(ctx.searchError == nil)
    for (childType, parentIdx) in zip(ctx.freeUnifications, ctx.freeParents) {
      // Note: freeUnifications might now be larger than freeParents, due to addType.
      // These get ignored, because they cannot possibly be referenced by the parent context.
      guard let childType = childType else { continue } // not resolved by child
      let parentType = ctx.copyForParent(type: childType)
      if case .free(let i) = parentType.kind { assert(i != parentIdx) } // a free should never point to itself.
      freeUnifications[parentIdx] = parentType
    }
    for i in ctx.freeNevers {
      freeNevers.insert(ctx.freeParents[i])
    }
  }


  mutating func resolveRound() throws -> [Constraint] {
    var deferred: [Constraint] = []
    var i = 0
    while i < constraints.count { // use while loop because constraints array may grow during iteration.
      let constraint = constraints[i]
      let done = try resolve(constraint)
      if !done {
        deferred.append(constraint)
      }
      i += 1
    }
    return deferred
  }


  mutating func resolveAll() throws {
    while !constraints.isEmpty {
      searchError = nil
      let deferred = try resolveRound()
      if deferred.count == constraints.count { // no progress; error.
        if let searchError = searchError { error(searchError) }
        // If we do not have a specific error from polymorph search, just show generic error for first constraint.
        switch deferred.first! {
        case .prop(let prop): throw prop.error("cannot resolve constraint")
        case .rel(let rel): throw rel.error({(_, _) in "cannot resolve constraint"})
        }
      }
      constraints = deferred
    }
    // fill in frees that were only bound to Never.
    for idx in freeNevers {
      if freeUnifications[idx] == nil {
        freeUnifications[idx] = typeNever
      }
    }
  }


  mutating func resolveOrError() {
    do {
      try resolveAll()
    } catch let err as PropCon.Err {
      error(err)
    } catch let err as RelCon.Err {
      error(err)
    } catch { fatalError() }
  }


  func error(_ err: PropCon.Err) -> Never {
    let accesseeType = resolved(type: err.prop.accesseeType)
    err.prop.acc.accessee.form.failType("\(err.msg). accessee type: \(accesseeType)",
      notes: (err.prop.acc.accessor.form, "accessor is here."))
  }


  func error(_ err: RelCon.Err) -> Never {
    let r = err.rel
    let msg = err.msgThunk(r.act.role.desc, r.exp.role.desc)
    let act = resolved(type: r.act.type)
    let exp = resolved(type: r.exp.type)
    if r.act.expr != r.exp.expr {
      r.act.expr.form.failType("\(r.desc) \(msg). \(r.act.chainDesc)\(r.act.role.desc) type: \(act)",
        notes: (r.exp.expr.form, "\(r.exp.chainDesc)\(r.exp.role.desc) type: \(exp)"))
    } else {
      r.act.expr.form.failType("\(r.desc) \(msg).\n  \(r.act.chainDesc)\(r.act.role.desc) type: \(act)" +
        "\n  \(r.exp.chainDesc)\(r.exp.role.desc) type: \(exp)")
    }
  }


  func describeState(_ label: String = "", showConstraints: Bool = false, showUnifications: Bool = true) {
    errL("TypeCtx.describeState: \(label)")
    if showConstraints {
      errL("Constraints:")
      for c in constraints {
        errL("  \(c)")
      }
    }
    if showUnifications {
      errL("Unifications:")
      for (i, origType) in freeUnifications.enumerated() {
        let never = freeNevers.contains(i) ? " (Never)" : ""
        if let origType = origType {
          let type = resolved(type: origType)
          let frees = type.childFrees.isEmpty ? "" : " : \(type.childFrees.sorted())"
          errL("  \(i): \(origType)\t-- \(type)\(never)\(frees)")
        } else {
          errL("  \(i): nil\(never)")
        }
      }
    }
    errN()
  }
}
