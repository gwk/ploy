// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  typealias MsgThunk = ()->String

  struct Err: Error {
    let rel: Rel
    let msgThunk: MsgThunk

    init(_ rel: Rel, _ msgThunk: @escaping @autoclosure ()->String) {
      self.rel = rel
      self.msgThunk = msgThunk
    }
  }


  struct PropErr: Error {
    let prop: Prop
    let msg: String
  }


  let globalCtx: GlobalCtx
  private var constraints: [Constraint] = []
  private var freeTypeCount = 0
  private var freeUnifications: [Int:Type] = [:]
  private var exprTypes = [Expr:Type]() // maps expressions to their latest types.
  private var exprOrigs = [Expr:Type]() // maps expressions to pre-conversion types.
  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()


  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }


  func typeFor(expr: Expr) -> Type {
    return resolved(type: exprTypes[expr]!)
  }


  func origFor(expr: Expr) -> Type? {
    if let orig = exprOrigs[expr] {
      return resolved(type: orig)
    }
    return nil
  }


  mutating func addFreeType() -> Type {
    let t = Type.Free(freeTypeCount)
    freeTypeCount += 1
    return t
  }


  mutating func track(expr: Expr, type: Type) {
    exprTypes.insertNew(expr, value: type)
  }


  mutating func track(typeExpr: Expr, type: Type) {
    exprTypes.insertNew(typeExpr, value: type)
  }

  mutating func constrain(_ actExpr: Expr, actType: Type, expExpr: Expr? = nil, expType: Type, _ desc: String) {
    constraints.append(.rel(Rel(
      act: Side(expr: actExpr, type: actType),
      exp: Side(expr: expExpr.or(actExpr), type: expType),
      desc: desc)))
  }


  mutating func constrain(prop: Prop) {
    constraints.append(.prop(prop))
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
    case .sig(let dom, let ret):
      return Type.Sig(dom: resolved(type: dom), ret: resolved(type: ret))
    case .var_: return type
    }
  }


  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return (type == par.type) ? par : TypeField(label: par.label, type: type)
  }


  mutating func unify(freeIndex: Int, to type: Type) -> Type {
    assert(!freeUnifications.contains(key: freeIndex))
    freeUnifications[freeIndex] = type
    return type
  }


  mutating func resolve(_ constraint: Constraint) throws -> Type {
    let type: Type
    let litExpr: Expr?
    switch constraint {
    case .rel(let rel):
      type = try resolve(rel: rel)
      litExpr = rel.act.litExpr
    case .prop(let prop):
      type = try resolve(prop: prop)
      litExpr = .acc(prop.acc)
    }
    if let litExpr = litExpr {
      exprTypes[litExpr] = type
    }
    return type
  }


  mutating func resolve(rel: Rel) throws -> Type {
    let act: Type
    if let lit = rel.act.litExpr {
      // if the expression has an associated type then use that, because it may have been refined.
      // however, the litExpr might refer to a type expression, in which case it will not have an associated type.
      act = resolved(type: exprTypes[lit].or(rel.act.type))
    } else {
      act = resolved(type: rel.act.type)
    }
    let exp = resolved(type: rel.exp.type)
    if (act == exp) {
      return act
    }

    switch (act.kind, exp.kind) {

    case (.free(let ia), .free(let ie)):
      // TODO: determine whether always resolving to lower index is necessary.
      if ia > ie { return unify(freeIndex: ia, to: exp) }
      else {       return unify(freeIndex: ie, to: act) }

    case (.free(let ia), _): return unify(freeIndex: ia, to: exp)
    case (_, .free(let ie)): return unify(freeIndex: ie, to: act)

    case (.poly(let morphs), _):
      var match: (TypeCtx, Type)? = nil
      for morph in morphs {
        var ctx = self // copy ctx.
        let res: Type
        do {
          res = try ctx.resolveSub(rel, actType: morph, actDesc: "morph")
        } catch {
          continue
        }
        if let (_, prev) = match { throw Err(rel, "multiple morphs match expected: \(prev); \(res)") }
        match = (ctx, res)
      }
      guard let (ctx, morph) = match else { throw Err(rel, "no morphs match expected") }
      self = ctx
      return morph

    case (_, .any(let members)):
      if !members.contains(act) {
        throw Err(rel, "actual type is not a member of `Any` expected type")
      }
      return act

    case (.cmpd(let actFields), .cmpd(let expFields)):
      return try resolveCmpdToCmpd(rel, act: act, actFields: actFields, expFields: expFields)

    case (.sig(let actDom, let actRet), .sig(let expDom, let expRet)):
      return try resolveSigToSig(rel, actDom: actDom, actRet: actRet, expDom: expDom, expRet: expRet)

    default: throw Err(rel, "actual type is not expected type")
    }
  }


  mutating func resolveCmpdToCmpd(_ rel: Rel, act: Type, actFields: [TypeField], expFields: [TypeField]) throws -> Type {
    if expFields.count != actFields.count {
      let nFields = pluralize(actFields.count, "field")
      throw Err(rel, "actual struct has \(nFields); expected \(expFields.count)")
    }
    let litActFields = rel.act.litExpr?.cmpdFields
    let litExpFields = rel.exp.litExpr?.cmpdFields
    var origFields: [TypeField] = []
    var castFields: [TypeField] = []
    var isConv = false
    for (index, (actField, expField)) in zip(actFields, expFields).enumerated() {
      if actField.label != nil {
        if actField.label != expField.label {
          throw Err(rel, "field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)")
        }
      } else if expField.label != nil { // convert unlabeled to labeled.
        isConv = true
      }
      let fieldType = try resolveSub(rel,
        actExpr: litActFields?[index], actType: actField.type, actDesc: "field \(index)",
        expExpr: litExpFields?[index], expType: expField.type, expDesc: "field \(index)")
      origFields.append(TypeField(label: actField.label, type: fieldType))
      castFields.append(TypeField(label: expField.label, type: fieldType))
    }
    if isConv {
      if let expr = rel.act.litExpr, exprTypes.contains(key: expr) {
        exprOrigs[expr] = Type.Cmpd(origFields)
      } else {
        throw Err(rel, "struct type cannot be converted without a literal expression")
      }
    } else {
      assert(origFields == castFields)
    }
    return Type.Cmpd(castFields)
  }


  mutating func resolveSigToSig(_ rel: Rel, actDom: Type, actRet: Type, expDom: Type, expRet: Type) throws -> Type {
    let domType = try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigDom, actType: actDom, actDesc: "signature domain",
      expExpr: rel.exp.litExpr?.sigDom, expType: expDom, expDesc: "signature domain")
    let retType = try resolveSub(rel,
      actExpr: rel.act.litExpr?.sigRet, actType: actRet, actDesc: "signature return",
      expExpr: rel.exp.litExpr?.sigRet, expType: expRet, expDesc: "signature return")
    return Type.Sig(dom: domType, ret: retType)
  }


  mutating func resolve(prop: Prop) throws -> Type {
    let accesseeType = resolved(type: prop.accesseeType)
    let accType = resolved(type: prop.accType)
    switch accesseeType.kind {
    case .cmpd(let fields):
      for (i, field) in fields.enumerated() {
        if field.accessorString(index: i) == prop.acc.accessor.propAccessor.accessorString {
          exprTypes[.acc(prop.acc)] = field.type // TOTAL HACK.
          return try resolve(.rel(Rel(
            act: Side(expr: .acc(prop.acc), type: field.type),
            exp: Side(expr: .acc(prop.acc), type: accType), // originally a free, but may have resolved.
            desc: "access")))
        }
      }
      throw PropErr(prop: prop, msg: "accessee has no field matching accessor")
    default: throw PropErr(prop: prop, msg: "accessee is not a struct")
    }
  }


  mutating func resolveSub(_ rel: Rel,
   actExpr: Expr?, actType: Type, actDesc: String,
   expExpr: Expr?, expType: Type, expDesc: String) throws -> Type {
    let sub = Constraint.rel(Rel(
      act: rel.act.sub(expr: actExpr, type: actType, desc: actDesc),
      exp: rel.exp.sub(expr: expExpr, type: expType, desc: expDesc),
      desc: rel.desc))
    return try resolve(sub)
  }


  mutating func resolveSub(_ rel: Rel, actType: Type, actDesc: String) throws -> Type {
    let a = rel.act
    let sub = Constraint.rel(Rel(
      act: Side(expr: a.expr, type: actType, chain: .link(actDesc, a.chain)),
      exp: rel.exp,
      desc: rel.desc))
    return try resolve(sub)
  }


  func error(err: Err) -> Never {
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


  func error(prop: Prop, msg: String) -> Never {
    let accesseeType = resolved(type: prop.accesseeType)
    prop.acc.accessee.form.failType("\(msg). accessee type: \(accesseeType)",
      notes: (prop.acc.accessor.form, "accessor is here."))
  }


  mutating func resolveAll() {

    for constraint in constraints {
      do {
        _ = try resolve(constraint)
      } catch let err as Err {
        error(err: err)
      } catch let err as PropErr {
        error(prop: err.prop, msg: err.msg)
      } catch { fatalError() }
    }

    // check that resolution is complete.
    for expr in exprTypes.keys {
      let type = typeFor(expr: expr)
      if type.frees.count > 0 {
        fatalError("unresolved frees in type: \(type)")
      }
    }
  }
}
