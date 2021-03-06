// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx: Encodable {

  enum CodingKeys: CodingKey {
    case constraints
    case freeUnifications
    case freeParents
    case freeNevers
    case searchError
  }

  var constraints = [Constraint]()
  var unresolvedIndices = [Int]()
  var freeUnifications = [Type?]()
  var freeParents: [Int] = [] // Map free indices to parent context.
  var freeNevers = Set<Int>() // Never types are a special case, omitted from unification.
  var selectedMethods = [Sym:Type]()

  var searchError: RelCon.Err? = nil
  var dumpMethodResolutionErrors = false


  mutating func addFreeType() -> Type {
    let idx = freeUnifications.count
    freeUnifications.append(nil)
    return Type.Free(idx)
  }


  mutating func addConstraint(_ constraint: Constraint) {
    unresolvedIndices.append(constraints.count)
    constraints.append(constraint)
  }


  func resolved(type: Type) -> Type {
    // TODO: need to track types to prevent/handle recursion?
    if type.isResolved { return type }
    switch type.kind {
    case .intersect(let members):
      return try! Type.Intersect(members.map { self.resolved(type: $0) })
    case .union(let members):
      return try! Type.Union(members.map { self.resolved(type: $0) })
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

    case (.poly, .intersect): throw rel.error({"\($0) to \($1) intersection not yet implemented"})

    case (.poly, .union): throw rel.error({"\($0) to \($1) union not yet implemented"})

    case (.poly, _): throw rel.error({"\($0) cannot resolve against \($1) type"})

    case (.free(let ia), .free):
      // Propagate the actual type as far as possible. TODO: figure out if this matters.
      unify(freeIndex: ia, to: exp)
      return true

    case (.free(let ia), _):
      // If expected is Never then it is ok to unify; the caller expects to never return.
      unify(freeIndex: ia, to: exp)
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

    case (.intersect(let actMembers), .intersect(let expMembers)):
      for expMember in expMembers {
        if !actMembers.contains(expMember) {
          throw rel.error({"\($0) intersection type is not superset of intersection \($1) type; missing member: `\(expMember)`"})
        }
      }
      return true

    case (_, .intersect(let expMembers)):
      for expMember in expMembers {
        try resolveSub(rel,
          actType: act, actDesc: "type",
          expType: expMember, expDesc: "intersection member")
      }
      return true

    case (.intersect(let actMembers), _): // Not sure how much sense this makes.
      for actMember in actMembers {
        try resolveSub(rel,
          actType: actMember, actDesc: "intersection member",
          expType: exp, expDesc: "type")
      }
      return true

    case (.union(let actMembers), .union(let expMembers)):
      for actMember in actMembers {
        if !expMembers.contains(actMember) {
          throw rel.error({"\($0) union type is not subset of union \($1) type; outstanding member: `\(actMember)`"})
        }
      }
      return true

    case (_, .union(let members)):
      if !members.contains(act) {
        throw rel.error({"\($0) type is not a member of union \($1) type"})
      }
      return true

    case (.sig(let actDR), .sig(let expDR)):
      return try resolveSigToSig(rel, act: actDR, exp: expDR)

    case (.struct_(let actFV), .struct_(let expFV)):
      if exp == typeNull {
        throw rel.error({(_, _) in "implicit struct conversion to nil is disallowed"})
      }
      return try resolveStructToStruct(rel, act: actFV, exp: expFV)

    case (.struct_(_, _, let actVariants), .variantMember(let expVariant)):
      return try resolveStructToVariantMember(rel, actVariants: actVariants, expVariant: expVariant)

    case (_, .prim) where exp == typeAny:
      return true
    default: throw rel.error({"\($0) type is not \($1) type"})
    }
  }


  enum MethodResult {
    case none
    case match(Type)
    case multiple(Type, Type)
  }

  mutating func resolveMethodsToExp(_ rel: RelCon, act: Type, exp: Type, actMorphs: [Type], merge: Bool) -> MethodResult {
    // returns matching morph type.
    let (subCtx, subExp) = subCtxAndType(parentType: exp)
    var matchMethod: Type? = nil
    var matchCtx = TypeCtx() // overwritten by matching iteration.
    for actMorph in actMorphs {
      var childCtx = subCtx // copy.
      let morph = childCtx.instantiate(expr: rel.act.expr, type: actMorph)
      childCtx.addConstraint(.rel(RelCon(
        act: Side(.act, expr: rel.act.expr, type: morph, chain: .link("morph", rel.act.chain)), // ok to pass morph directly, because it is resolved.
        exp: Side(.exp, expr: rel.exp.expr, type: subExp, chain: rel.exp.chain),
        desc: rel.desc)))
      do { try childCtx.resolveAll() }
      catch let e {
        if childCtx.dumpMethodResolutionErrors {
          rel.act.expr.diagnostic(prefix: "PLOY_DBG_DEFS", msg: "morph: \(morph); error: \(e)")
        }
        // TODO: return search error?
        continue
      }
      let resolvedMorph = childCtx.resolved(type: morph)
      if let prev = matchMethod {
        return .multiple(prev, resolvedMorph)
      }
      matchMethod = resolvedMorph
      matchCtx = childCtx
    }
    if let matchMethod = matchMethod {
      if merge { mergeSubCtx(matchCtx) } // Unifies the free of the poly ref to the morph, plus any others, e.g. expSig.ret.
      return .match(matchMethod)
    }
    return .none
  }


  mutating func resolvePolyToSig(_ rel: RelCon, act: Type, exp: Type) throws -> Bool {
    guard case .poly(let actMorphs) = act.kind else { fatalError() }
    let (expDom, expRet) = exp.sigDomRet
    let sym = rel.act.expr.identifierLastSym

    switch resolveMethodsToExp(rel, act: act, exp: exp, actMorphs: actMorphs, merge: true) {
    case .none: break
    case .match(let morph):
      selectedMethods.insertNew(sym, value: morph)
      return true
    case .multiple(let prev, let match):
      if searchError == nil { searchError = rel.error({"multiple methods of \($0) match \($1): \(prev), \(match)"}) }
      return false
    }

    // No match; attempt to cover the union case.
    guard case .union(let expDomMembers) = expDom.kind else { throw rel.error({"no methods of \($0) match \($1) type"}) }

    if !expDom.isResolved { // cannot synthesize with an unresolved expected domain.
      if searchError == nil { searchError = rel.error({"cannot synthesize \($0) polyfunction against unresolved \($1) union domain"}) }
      return false
    }

    // Synthesize a method that matches the expected union dom.
    var reqMorphs = [Type]() // Subset of morphs that are relevant.
    for expDomMember in expDomMembers {
      let expMemberSig = Type.Sig(dom: expDomMember, ret: expRet)
      switch resolveMethodsToExp(rel, act: act, exp: expMemberSig, actMorphs: actMorphs, merge: false) {
      case .none:
        throw rel.error({"no morphs of \($0) match \($1) domain member: \(expDomMember)"})
      case .match(let morph):
        reqMorphs.append(morph)
       case .multiple(let m0, let m1):
        if searchError == nil { searchError = rel.error({"multiple methods of \($0) match \($1): \(m0), \(m1)"}) }
        return false
      }
    }
    reqMorphs.sort()
    let method = Type.Poly(reqMorphs)
    let (actDom, actRet) = method.polyDomRet
    try resolveSub(rel, // Note: this is excessive, beceause we just constructed the domain ourselves, but it does not hurt.
      actType: actDom, actDesc: "polyfunction domain",
      expType: expDom, expDesc: "signature domain")
    try resolveSub(rel,
      actType: actRet, actDesc: "polyfunction return",
      expType: expRet, expDesc: "signature return")

    selectedMethods.insertNew(sym, value: method)
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
          actType: actVariant.type, actDesc: "variant",
          expType: expVariant.type, expDesc: "variant")
        return true
      }
    }
    throw rel.error({"\($0) variants do not contain \($1) variant label: `-\(expVariant.label)`"})
  }


  mutating func resolveSub(constraint: Constraint) throws {
    let index = constraints.count
    constraints.append(constraint)
    let done = try resolve(constraint)
    if !done {
      unresolvedIndices.append(index)
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


  mutating func instantiate(expr: Expr, type: Type) -> Type {
    if !type.isResolved { expr.fatal("instantiate received unresolved type: \(type)") }
    if type.isConcrete { return type }
    var varsToFrees: [String:Type] = [:]
    let t = instantiate(expr, type, &varsToFrees)
    assert(!t.isResolved)
    assert(t.isConcrete)
    return t
  }


  mutating func instantiate(_ expr: Expr, _ type: Type, _ varsToFrees: inout [String:Type]) -> Type {
    if type.isConcrete { return type }
    switch type.kind {
    case .free, .host, .prim: fatalError()
    case .intersect(let members): return try! .Intersect(members.map { self.instantiate(expr, $0, &varsToFrees) })
    case .poly(let members): return .Poly(members.map { self.instantiate(expr, $0, &varsToFrees) })
    case .refinement(let base, let pred): return .Refinement(base: self.instantiate(expr, base, &varsToFrees), pred: pred)
    case .req(let base, let requirement):
      let type = self.instantiate(expr, base, &varsToFrees)
      constrain(actExpr: expr, actType: type, expType: requirement, "type requirement")
      return type
    case .sig(let dom, let ret):
      return .Sig(dom: instantiate(expr, dom, &varsToFrees), ret: instantiate(expr, ret, &varsToFrees))
    case .struct_(let posFields, let labFields, let variants):
      return .Struct(
        posFields: posFields.map { self.instantiate(expr, $0, &varsToFrees) },
        labFields: labFields.map { $0.substitute(type: self.instantiate(expr, $0.type, &varsToFrees)) },
        variants: variants.map { $0.substitute(type: self.instantiate(expr, $0.type, &varsToFrees)) })
    case .union(let members): return try! .Union(members.map { self.instantiate(expr, $0, &varsToFrees) })
    case .var_(let name):
      return varsToFrees.getOrInsert(name, dflt: { self.addFreeType() })
    case .variantMember(let variant):
      return .VariantMember(variant: variant.substitute(type: instantiate(expr, variant.type, &varsToFrees)))
    }
  }


  mutating func constrain(
   actRole: Side.Role = .act, actExpr: Expr, actType: Type,
   expRole: Side.Role = .exp, expExpr: Expr? = nil, expType: Type, _ desc: String) {
    addConstraint(.rel(RelCon(
      act: Side(actRole, expr: actExpr, type: actType),
      exp: Side(expRole, expr: expExpr ?? actExpr, type: expType),
      desc: desc)))
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
      // TODO: eventually fix this for the sake of complete context dumping.
      guard let childType = childType else { continue } // not resolved by child.
      let parentType = ctx.copyForParent(type: childType)
      if case .free(let i) = parentType.kind { assert(i != parentIdx) } // a free should never point to itself.
      freeUnifications[parentIdx] = parentType
    }
    for i in ctx.freeNevers {
      freeNevers.insert(ctx.freeParents[i])
    }
    selectedMethods.merge(ctx.selectedMethods) {
      fatalError("conflicting selected methods:\n  \($0)\n  \($1)")
    }
  }


  mutating func resolveRound() throws -> [Int] {
    var deferredIndices = [Int]()
    var i = 0
    while i < unresolvedIndices.count { // Use while loop because constraints array may grow during iteration.
      let idx = unresolvedIndices[i]
      let constraint = constraints[idx]
      let resolved = try resolve(constraint)
      if !resolved {
        deferredIndices.append(idx)
      }
      i += 1
    }
    return deferredIndices
  }


  mutating func resolveAll() throws {
    while !unresolvedIndices.isEmpty {
      searchError = nil
      let deferredIndices = try resolveRound()
      if deferredIndices.count == unresolvedIndices.count { // No progress; error.
        if let searchError = searchError { throw searchError }
        // If we do not have a specific error from polymorph search, just show generic error for first constraint.
        switch constraints[deferredIndices.first!] {
        case .prop(let prop): throw prop.error("cannot resolve constraint")
        case .rel(let rel): throw rel.error({(_, _) in "cannot resolve constraint"})
        }
      }
      unresolvedIndices = deferredIndices
    }
  }


  mutating func fillFreeNevers() {
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
      r.act.expr.failType("\(r.desc) \(msg).\n"
      + "  \(r.act.chainDesc)\(r.act.role.desc) type: \(act)\n"
      + "  \(r.exp.chainDesc)\(r.exp.role.desc) type: \(exp)")
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
          let frees = type.isResolved ? "" : " : \(type.childFrees.sorted())"
          errL("  \(i): \(origType)\t-- \(type)\(never)\(frees)")
        } else {
          errL("  \(i): nil\(never)")
        }
      }
    }
    errN()
  }
}
