// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  var constraints = [Constraint]()
  var freeUnifications = [Type?]()
  var freeParents: [Int] = [] // Map free indices to parent context.
  var freeNevers = Set<Int>() // Never types are a special case, omitted from unification.

  var searchError: RelCon.Err? = nil
  var dumpMethodResolutionErrors = false

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
    case .struct_(let posFields, let labFields, let variants):
      return Type.Struct(
        posFields: posFields.map() { self.resolved(type: $0) },
        labFields: labFields.map() { TypeLabField(label: $0.label, type: self.resolved(type: $0.type)) },
        variants: variants.map() { TypeVariant(label: $0.label, type: self.resolved(type: $0.type)) })
    case .free(let freeIndex):
      if let substitution = freeUnifications[freeIndex] {
        return resolved(type: substitution)
      } else { return type }
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    case .variantMember(let variant):
      return Type.VariantMember(variant: TypeVariant(label: variant.label, type: resolved(type: variant.type)))
    default: fatalError("type kind cannot contain frees: \(type)")
    }
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
    case .struct_(let posFields, let labFields, let variants):
      if case .untag(let tag) = accessor {
        let name = tag.sym.name
        for variant in variants {
          if variant.label == name {
            try resolveSub(constraint: .rel(RelCon(
              act: Side(.act, expr: .acc(prop.acc), type: variant.type),
              exp: Side(.exp, expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
              desc: "variant")))
            return true
          }
        }
        throw prop.error("accessee has no variant named `\(name)`")
      } else {
        for (i, fieldType) in posFields.enumerated() {
          if String(i) == accessor.accessorString {
            try resolveSub(constraint: .rel(RelCon(
              act: Side(.act, expr: .acc(prop.acc), type: fieldType),
              exp: Side(.exp, expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
              desc: "access")))
            return true
          }
        }
        for field in labFields {
          if field.accessorString == accessor.accessorString {
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

    case (.poly, .free): // cannot resolve polyfunction against free because it prevents method selection; defer instead.
      if searchError == nil { searchError = rel.error({"\($0) cannot resolve against \($1) free type"}) }
      return false

    case (.poly, .sig): // select a single morph.
      return try resolvePolyToSig(rel, act: act, exp: exp)

    case (.poly, .method): throw rel.error({"\($0) to \($1) polyfunctions not yet implemented"})

    case (.poly, .all): throw rel.error({"\($0) to \($1) intersection not yet implemented"})

    case (.poly, .any): throw rel.error({"\($0) to \($1) union not yet implemented"})

    case (.poly, _): throw rel.error({"\($0) cannot resolve against \($1) type"})

    case (.free(let ia), .free):
      // Propagate the actual type as far as possible. TODO: figure out if this matters.
      unify(freeIndex: ia, to: exp)
      return true

    case (.free(let ia), _):
      // If expected is Never then it is ok to unify; the caller expects to never return.
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

    case (.all(let actMembers), .all(let expMembers)):
      for expMember in expMembers {
        if !actMembers.contains(expMember) {
          throw rel.error({"\($0) `All` type is not superset of `Any` \($1) type; missing member: `\(expMember)`"})
        }
      }
      return true

    case (_, .all(let expMembers)):
      for expMember in expMembers {
        try resolveSub(rel,
          actType: act, actDesc: "type",
          expType: expMember, expDesc: "`All` member")
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

    case (.method, .sig):
      return try resolveMethodToSig(rel, act: act, exp: exp)

    case (.sig(let actDR), .sig(let expDR)):
      return try resolveSigToSig(rel, act: actDR, exp: expDR)

    case (.struct_(let actFV), .struct_(let expFV)):
      if exp == typeNull {
        throw rel.error({(_, _) in "implicit struct conversion to nil is disallowed"})
      }
      return try resolveStructToStruct(rel, act: actFV, exp: expFV)

    case (.struct_(_, _, let actVariants), .variantMember(let expVariant)):
      return try resolveStructToVariantMember(rel, actVariants: actVariants, expVariant: expVariant)

    default: throw rel.error({"\($0) type is not \($1) type"})
    }
  }

  enum MethodResult {
    case none
    case match(Type)
    case multiple(Type, Type)
  }

  mutating func resolveMethodsToExp(_ rel: RelCon, act: Type, exp: Type, morphs: [Type], merge: Bool) -> MethodResult {
    // returns matching morph type.
    let (subCtx, subExp) = subCtxAndType(parentType: exp)
    var matchMethod: Type? = nil
    var matchCtx = TypeCtx() // overwritten by matching iteration.
    for morph in morphs {
      assert(morph.isResolved)
      assert(morph.vars.isEmpty) // TODO: support generic implementations in extensibles?
      var childCtx = subCtx // copy.
      //errL(""); childCtx.describeState("MORPH: \(morph); EXP: \(subExp)")
      childCtx.addConstraint(.rel(RelCon(
        act: Side(.act, expr: rel.act.expr, type: morph, chain: .link("morph", rel.act.chain)), // ok to pass morph directly, because it is resolved.
        exp: Side(.exp, expr: rel.exp.expr, type: subExp, chain: rel.exp.chain),
        desc: rel.desc)))
      do { try childCtx.resolveAll() }
      catch let e {
        if childCtx.dumpMethodResolutionErrors {
          errL("DEBUG: PLOY_DBG_METHODS: morph: \(morph); error: \(e)")
        }
        // TODO: return search error?
        continue
      }
      if let prev = matchMethod {
        return .multiple(prev, morph)
      }
      matchMethod = morph
      matchCtx = childCtx
    }
    if let matchMethod = matchMethod {
      if merge { mergeSubCtx(matchCtx) } // unifies the poly ref free to the morph, plus any others, e.g. expSig.ret.
      return .match(matchMethod)
    }
    return .none
  }


  mutating func resolvePolyToSig(_ rel: RelCon, act: Type, exp: Type) throws -> Bool {
    guard case .poly(let morphs) = act.kind else { fatalError() }
    guard case .sig(let expDom, let expRet) = exp.kind else { fatalError() }

    switch resolveMethodsToExp(rel, act: act, exp: exp, morphs: morphs, merge: true) {
    case .none: break
    case .match: return true
    case .multiple(let prev, let match):
      if searchError == nil { searchError = rel.error({"multiple methods of \($0) match \($1): \(prev), \(match)"}) }
      return false
    }

    guard case .any(let expDomMembers) = expDom.kind else { throw rel.error({"no methods of \($0) match \($1) type"}) }
    // no exact match, try to synthesize a method that matches the expected union dom.

    if !expDom.childFrees.isEmpty { // cannot synthesize with an unresolved expected domain.
      if searchError == nil { searchError = rel.error({"cannot synthesize \($0) polyfunction against free \($1) union domain"}) }
      return false
    }

    var reqMethods: [Type] = [] // subset of morphs that are relevant.
    for expDomMember in expDomMembers {
      let expMemberSig = Type.Sig(dom: expDomMember, ret: expRet)
      switch resolveMethodsToExp(rel, act: act, exp: expMemberSig, morphs: morphs, merge: false) {
      case .none:
        throw rel.error({"no morphs of \($0) match \($1) domain member: \(expDomMember)"})
      case .match(let morph):
        reqMethods.append(morph)
      case .multiple(let m0, let m1):
        if searchError == nil { searchError = rel.error({"multiple methods of \($0) match \($1): \(m0), \(m1)"}) }
        return false
      }
    }
    let method = Type.Method(reqMethods)
    try resolveSub(rel,
      actType: method, actDesc: "method",
      expType: exp, expDesc: "signature")
    return true
  }


  mutating func resolveMethodToSig(_ rel: RelCon, act: Type, exp: Type) throws -> Bool {
    guard case .method(let morphs) = act.kind else { fatalError() }
    guard case .sig(let expDom, let expRet) = exp.kind else { fatalError() }

    switch resolveMethodsToExp(rel, act: act, exp: exp, morphs: morphs, merge: true) {
    case .none: break
    case .match: return true
    case .multiple(let m0, let m1):
      if searchError == nil { searchError = rel.error({"multiple methods of \($0) polyfunction match \($1): \(m0), \(m1)"}) }
      return false
    }

    guard case .any(let expDomMembers) = expDom.kind else { throw rel.error({"no methods of \($0) polyfunction match \($1) type"}) }
    // no exact match, try to synthesize a method that matches the expected union dom.

    if !expDom.childFrees.isEmpty { // cannot synthesize with an unresolved expected domain.
      if searchError == nil { searchError = rel.error({"cannot synthesize \($0) polyfunction against unresolved \($1) union domain"}) }
      return false
    }

    var reqMethods: [Type] = [] // subset of morphs that are relevant.
    for expDomMember in expDomMembers {
      let expMemberSig = Type.Sig(dom: expDomMember, ret: expRet)
      switch resolveMethodsToExp(rel, act: act, exp: expMemberSig, morphs: morphs, merge: false) {
      case .none:
        throw rel.error({"no methods of \($0) polyfunction match \($1) domain: \(expDom)"})
      case .match(let match):
        reqMethods.append(match)
      case .multiple(let m0, let m1):
        if searchError == nil { searchError = rel.error({"multiple methods of \($0) polyfunction match \($1): \(m0), \(m1)"}) }
        return false
      }
    }
    let reqRets = Set(reqMethods.map({$0.sigRet})).sorted()
    let actRet = try Type.Any_(reqRets)
    try resolveSub(rel,
      actType: actRet, actDesc: "polyfunction return",
      expType: expRet, expDesc: "signature return")
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
   act: (posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant]),
   exp: (posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant])) throws -> Bool {

    let actLitMembers = rel.act.litExpr?.parenMembers
    let expLitMembers = rel.exp.litExpr?.parenMembers

    let epc = exp.posFields.count
    let apc = act.posFields.count
    let alc = act.labFields.count
    let afc = apc + alc
    let efc = epc + exp.labFields.count
    var ai = 0

    // Positional fields.
    for (ei, expType) in exp.posFields.enumerated() {
      if ai == apc {
        let act_pos_fields = pluralize(apc, "positional field")
        throw rel.error({"\($0) struct has \(act_pos_fields); \($1) struct has \(epc)"})
      }
      let actType = act.posFields[ai]
      try resolveSub(rel,
        actExpr: actLitMembers?[ai], actType: actType, actDesc: "field \(ai)",
        expExpr: expLitMembers?[ei], expType: expType, expDesc: "field \(ei)")
      ai += 1
    }

    // Labeled Fields.
    for (ei, expField) in exp.labFields.enumerated() {
      let labelDesc = "field `\(expField.label)`"
      let actType: Type
      let actDesc: String
      if ai == afc {
          throw rel.error({"\($0) struct is missing \($1) field `\(expField.label)`"})
      } else if ai >= apc { // Actual labeled field; check that labels match.
        let actField = act.labFields[ai-apc]
        if actField.label != expField.label {
          throw rel.error({"\($0) field is labeled `\(actField.label)`; \($1) field is labeled `\(expField.label)`"})
        }
        actType = actField.type
        actDesc = labelDesc
      } else { // Actual positional field for expected labeled field.
        actType = act.posFields[ai]
        actDesc = "field \(ai)"
      }
      try resolveSub(rel,
        actExpr: actLitMembers?[ai], actType: actType, actDesc: actDesc,
        expExpr: expLitMembers?[epc+ei], expType: expField.type, expDesc: labelDesc)
      ai += 1
    }
    if ai < apc {
      throw rel.error({"\($0) struct has extraneous positional field \(ai) not present in \($1) struct"})
    }
    if ai < afc {
      let actLabel = exp.labFields[ai-apc].label
      throw rel.error({"\($0) struct has extraneous labeled field `\(actLabel)` not present in \($1) struct"})
    }

    // Variants.
    let expVariants:[String:(Int, TypeVariant)] = Dictionary(uniqueKeysWithValues: exp.variants.enumerated().map{
      ($0.1.label, (efc + $0.0, $0.1))})

    while ai < afc + act.variants.count {
      let avi = ai - afc
      assertLT(avi, act.variants.count)
      let actVariant = act.variants[avi]
      let label = actVariant.label
      guard let (ei, expVariant) = expVariants[label] else {
        throw rel.error({"\($0) variant tag not found in \($1) variants: `-\(label)`"})
      }
      let desc = "variant `-\(label)`"
      try resolveSub(rel,
        actExpr: actLitMembers?[ai], actType: actVariant.type, actDesc: desc,
        expExpr: expLitMembers?[ei], expType: expVariant.type, expDesc: desc)
      ai += 1
    }
    return true
  }


  mutating func resolveStructToVariantMember(_ rel: RelCon, actVariants: [TypeVariant], expVariant: TypeVariant) throws -> Bool {
    for actVariant in actVariants {
      if actVariant.label == expVariant.label {
        try resolveSub(rel,
          actExpr: nil, actType: actVariant.type, actDesc: "variant",
          expExpr: nil, expType: expVariant.type, expDesc: "variant")
      return true
      }
    }
    throw rel.error({"\($0) variants do not contain \($1) variant label: `-\(expVariant.label)`"})
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
    subCtx.dumpMethodResolutionErrors = dumpMethodResolutionErrors
    let childType = subCtx.copy(parentType: parentType)
    return (subCtx, childType)
  }


  mutating func mergeSubCtx(_ ctx: TypeCtx) {
    assert(ctx.searchError == nil)
    for (childType, parentIdx) in zip(ctx.freeUnifications, ctx.freeParents) {
      // Note: freeUnifications might now be larger than freeParents, due to addType.
      // These get ignored by zip; ok because they cannot possibly be referenced by the parent context.
      guard let childType = childType else { continue } // not resolved by child.
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
  }


  mutating func resolveOrError() {
    do {
      try resolveAll()
    } catch let err as PropCon.Err {
      error(err)
    } catch let err as RelCon.Err {
      error(err)
    } catch { fatalError() }
    // fill in frees that were only bound to Never.
    for idx in freeNevers {
      if freeUnifications[idx] == nil {
        freeUnifications[idx] = typeNever
      }
    }
  }


  func error(_ err: PropCon.Err) -> Never {
    let accesseeType = resolved(type: err.prop.accesseeType)
    err.prop.acc.accessee.failType("\(err.msg). accessee type: \(accesseeType)",
      notes: (err.prop.acc.accessor, "accessor is here."))
  }


  func error(_ err: RelCon.Err) -> Never {
    let r = err.rel
    let msg = err.msgThunk(r.act.role.desc, r.exp.role.desc)
    let act = resolved(type: r.act.type)
    let exp = resolved(type: r.exp.type)
    if r.act.expr != r.exp.expr {
      r.act.expr.failType("\(r.desc) \(msg). \(r.act.chainDesc)\(r.act.role.desc) type: \(act)",
        notes: (r.exp.expr, "\(r.exp.chainDesc)\(r.exp.role.desc) type: \(exp)"))
    } else {
      r.act.expr.failType("\(r.desc) \(msg).\n  \(r.act.chainDesc)\(r.act.role.desc) type: \(act)" +
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
