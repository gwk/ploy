// © 2016 George King. Permission to use this file is granted in license.txt.


struct TypeCtx {

  typealias MsgThunk = ()->String

  struct Err: Error {
    let constraint: Constraint
    let msgThunk: MsgThunk

    init(_ constraint: Constraint, _ msgThunk: @escaping @autoclosure ()->String) {
      self.constraint = constraint
      self.msgThunk = msgThunk
    }
  }

  let globalCtx: GlobalCtx
  private var constraints: [Constraint] = []
  private var freeTypeCount = 0
  private var freeUnifications: [Int:Type] = [:]
  private var exprTypes = [Expr:Type]() // maps expressions to their latest types.
  private var exprOrigs = [Expr:Type]() // maps expressions to pre-conversion types.
  private var exprPolys = [Expr:Type]() // maps expressions to pre-narrowing types.
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


  func polyFor(expr: Expr) -> Type? {
    if let poly = exprPolys[expr] {
      return resolved(type: poly)
    }
    return nil
  }


  mutating func addFreeType() -> Type {
    let t = Type.Free(freeTypeCount)
    freeTypeCount += 1
    return t
  }


  mutating func trackExpr(_ expr: Expr, type: Type) {
    exprTypes.insertNew(expr, value: type)
  }


  mutating func constrain(_ actExpr: Expr, actType: Type, expExpr: Expr? = nil, expType: Type, _ desc: String) {
    constraints.append(Constraint(
      act: Constraint.Side(expr: actExpr, type: actType),
      exp: Constraint.Side(expr: expExpr.or(actExpr), type: expType),
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
    case .prop(let accessor, let accesseeType):
      let accType = resolved(type: accesseeType)
      switch accType.kind {
      case .cmpd(let fields):
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) == accessor.accessorString {
            return field.type
          }
        }
        fatalError("impossible prop type (TODO): \(type)")
      default: return Type.Prop(accessor, type: accType)
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


  mutating func unify(freeIndex: Int, to type: Type) -> Type {
    assert(!freeUnifications.contains(key: freeIndex))
    freeUnifications[freeIndex] = type
    return type
  }


  mutating func resolve(_ constraint: Constraint) throws -> Type {
    let type = try resolveDisp(constraint: constraint)
    if let expr = constraint.act.litExpr {
      exprTypes[expr] = type
    }
    return type
  }


  mutating func resolveDisp(constraint: Constraint) throws -> Type {
    let act: Type
    if let lit = constraint.act.litExpr {
      // if the expression has an associated type then use that, because it may have been refined.
      // however, the litExpr might refer to a type expression, in which case it will not have an associated type.
      act = resolved(type: exprTypes[lit].or(constraint.act.type))
    } else {
      act = resolved(type: constraint.act.type)
    }
    let exp = resolved(type: constraint.exp.type)
    if (act == exp) {
      return act
    }

    switch (act.kind, exp.kind) {

    case (.free(let ia), .free(let ie)):
      // TODO: determine whether always resolving to lower index is necessary.
      if ia > ie { return unify(freeIndex: ie, to: act) }
      else {       return unify(freeIndex: ia, to: exp) }

    case (.free(let ia), _): return unify(freeIndex: ia, to: exp)
    case (_, .free(let ie)): return unify(freeIndex: ie, to: act)

    case (.poly(let morphs), _):
      var match: (TypeCtx, Type)? = nil
      for morph in morphs {
        var ctx = self // copy ctx.
        let res: Type
        do {
          res = try ctx.resolveSub(constraint, actType: morph, actDesc: "morph")
        } catch {
          continue
        }
        if let (_, prev) = match { throw Err(constraint, "multiple morphs match expected: \(prev); \(res)") }
        match = (ctx, res)
      }
      guard let (ctx, morph) = match else { throw Err(constraint, "no morphs match expected") }
      self = ctx
      if let expr = constraint.act.litExpr, exprTypes.contains(key: expr) {
        exprPolys[expr] = act
      } else {
        throw Err(constraint, "polytype cannot select morph without a literal expression")
      }
      return morph

    case (.prop(let accessor, let accesseeType), _):
      let accType = resolved(type: accesseeType)
      switch accType.kind {
      case .cmpd(let fields):
        for (i, field) in fields.enumerated() {
          if field.accessorString(index: i) != accessor.accessorString { continue }
          return try resolveSub(constraint, actType: field.type, actDesc: "`\(field.accessorString(index: i))` property")
        }
        throw Err(constraint, "actual type has no field matching accessor")
      default: throw Err(constraint, "actual type is not an accessible type")
      }

    case (_, .any(let members)):
      if !members.contains(act) {
        throw Err(constraint, "actual type is not a member of `Any` expected type")
      }
      return act

    case (.cmpd(let actFields), .cmpd(let expFields)):
      return try resolveCmpdToCmpd(constraint, act: act, actFields: actFields, expFields: expFields)

    case (.sig(let actDom, let actRet), .sig(let expDom, let expRet)):
      return try resolveSigToSig(constraint, actDom: actDom, actRet: actRet, expDom: expDom, expRet: expRet)

    default: throw Err(constraint, "actual type is not expected type")
    }
  }


  mutating func resolveCmpdToCmpd(_ constraint: Constraint, act: Type, actFields: [TypeField], expFields: [TypeField]) throws -> Type {
    if expFields.count != actFields.count {
      let nFields = pluralize(actFields.count, "field")
      throw Err(constraint, "actual struct has \(nFields); expected \(expFields.count)")
    }
    let litActFields = constraint.act.litExpr?.cmpdFields
    let litExpFields = constraint.exp.litExpr?.cmpdFields
    var origFields: [TypeField] = []
    var castFields: [TypeField] = []
    var isConv = false
    for (index, (actField, expField)) in zip(actFields, expFields).enumerated() {
      if actField.label != nil {
        if actField.label != expField.label {
          throw Err(constraint, "field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)")
        }
      } else if expField.label != nil { // convert unlabeled to labeled.
        isConv = true
      }
      let fieldType = try resolveSub(constraint,
        actExpr: litActFields?[index], actType: actField.type, actDesc: "field \(index)",
        expExpr: litExpFields?[index], expType: expField.type, expDesc: "field \(index)")
      origFields.append(TypeField(label: actField.label, type: fieldType))
      castFields.append(TypeField(label: expField.label, type: fieldType))
    }
    if isConv {
      if let expr = constraint.act.litExpr, exprTypes.contains(key: expr) {
        exprOrigs[expr] = Type.Cmpd(origFields)
      } else {
        throw Err(constraint, "struct type cannot be converted without a literal expression")
      }
    } else {
      assert(origFields == castFields)
    }
    return Type.Cmpd(castFields)
  }


  mutating func resolveSigToSig(_ constraint: Constraint, actDom: Type, actRet: Type, expDom: Type, expRet: Type) throws -> Type {
    let domType = try resolveSub(constraint,
      actExpr: constraint.act.litExpr?.sigDom, actType: actDom, actDesc: "signature domain",
      expExpr: constraint.exp.litExpr?.sigDom, expType: expDom, expDesc: "signature domain")
    let retType = try resolveSub(constraint,
      actExpr: constraint.act.litExpr?.sigRet, actType: actRet, actDesc: "signature return",
      expExpr: constraint.exp.litExpr?.sigRet, expType: expRet, expDesc: "signature return")
    return Type.Sig(dom: domType, ret: retType)
  }


  mutating func resolveSub(_ constraint: Constraint,
   actExpr: Expr?, actType: Type, actDesc: String,
   expExpr: Expr?, expType: Type, expDesc: String) throws -> Type {
    let sub = Constraint(
      act: constraint.act.sub(expr: actExpr, type: actType, desc: actDesc),
      exp: constraint.exp.sub(expr: expExpr, type: expType, desc: expDesc),
      desc: constraint.desc)
    return try resolve(sub)
  }


  mutating func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String) throws -> Type {
    let a = constraint.act
    let sub = Constraint(
      act: Constraint.Side(expr: a.expr, type: actType, chain: .link(actDesc, a.chain)),
      exp: constraint.exp,
      desc: constraint.desc)
    return try resolve(sub)
  }


  func error(err: Err) -> Never {
    let c = err.constraint
    let msg = err.msgThunk()
    let act = resolved(type: c.act.type)
    let exp = resolved(type: c.exp.type)
    let actDesc = c.act.chain.map({"\($0) -> "}).join()
    let expDesc = c.exp.chain.map({"\($0) -> "}).join()

    if c.act.expr != c.exp.expr {
      c.act.expr.form.failType("\(c.desc) \(msg). \(actDesc)actual type: \(act)",
        notes: (c.exp.expr.form, "\(expDesc)expected type: \(exp)"))
    } else {
      c.act.expr.form.failType("\(c.desc) \(msg).\n  \(actDesc)actual type:   \(act);\n  \(expDesc)expected type: \(exp).")
    }
  }


  mutating func resolveAll() {

    for constraint in constraints {
      do {
        _ = try resolve(constraint)
      } catch let err as Err {
        error(err: err)
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
