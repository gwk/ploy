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

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()


  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }


  func typeFor(expr: Expr) -> Type {
    return resolved(type: exprTypes[expr]!)
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
    case .conv(let orig, let cast):
      return Type.Conv(orig: resolved(type: orig), cast: resolved(type: cast))
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
    case .sub(let orig, let cast):
      return Type.Sub(orig: resolved(type: orig), cast: resolved(type: cast))
    case .var_: return type
    }
  }


  private func resolved(par: TypeField) -> TypeField {
    let type = resolved(type: par.type)
    return (type == par.type) ? par : TypeField(label: par.label, type: type)
  }


  private func resolved(actType: Type) -> Type {
    switch actType.kind {
    case .conv(_, let cast), .sub(_, let cast): return resolved(actType: cast)
    default: return resolved(type: actType)
    }
  }


  mutating func unify(freeIndex: Int, to type: Type) -> Type {
    assert(!freeUnifications.contains(key: freeIndex))
    freeUnifications[freeIndex] = type
    return type
  }


  mutating func resolveConstraint(_ constraint: Constraint) throws -> Type {
    let act = resolved(actType: constraint.act.type)
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
      var match: Type? = nil
      for morph in morphs {
        do {
          let morph = try resolveSub(constraint, actType: morph, actDesc: "morph")
          if let prev = match { throw Err(constraint, "multiple morphs match expected: \(prev); \(morph)") }
          match = morph
        } catch {
          continue // TODO: this is broken because we should be unwinding any resolved types.
        }
      }
      guard let morph = match else { throw Err(constraint, "no morphs match expected") }
      let sub = Type.Sub(orig: act, cast: morph)
      assert(constraint.act.chain == .end)
      exprTypes[constraint.act.expr] = sub
      return sub

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

    case (_, .cmpd(let expFields)):
      return try resolveConstraintToCmpd(constraint, act: act, exp: exp, expFields: expFields)

    case (_, .sig(let expDom, let expRet)):
      return try resolveConstraintToSig(constraint, act: act, expDom: expDom, expRet: expRet)

    default: throw Err(constraint, "actual type is not expected type")
    }
  }


  mutating func resolveConstraintToCmpd(_ constraint: Constraint, act: Type, exp: Type, expFields: [TypeField]) throws -> Type {
    switch act.kind {

    case .cmpd(let actFields):
      if expFields.count != actFields.count {
        let actFields = pluralize(actFields.count, "field")
        throw Err(constraint, "actual struct has \(actFields); expected \(expFields.count)")
      }
      var isConv = false
      //let lexFields = constraint.act.expr.cmpdFields
      let fields = try enumZip(actFields, expFields).map {
        (index, actField, expField) -> TypeField in
        //let lexField = lexFields?[index]
        if actField.label != nil {
          if actField.label != expField.label {
            throw Err(constraint, "field #\(index) has \(actField.labelMsg); expected \(expField.labelMsg)")
          }
        } else if expField.label != nil { // convert unlabeled to labeled.
          isConv = true
        }
        // TODO: if let lexField = lexField...
        let fieldType = try resolveSub(constraint,
          actType: actField.type, actDesc: "field \(index)",
          expType: expField.type, expDesc: "field \(index)")
        return TypeField(label: expField.label, type: fieldType)
      }
      var type = Type.Cmpd(fields)
      if isConv {
        type = Type.Conv(orig: act, cast: type)
        assert(constraint.act.chain == .end)
        exprTypes[constraint.act.expr] = type
      }
      return type

    default: throw Err(constraint, "actual type is not a struct")
    }
  }


  mutating func resolveConstraintToSig(_ constraint: Constraint, act: Type, expDom: Type, expRet: Type) throws -> Type {
    switch act.kind {

    case .sig(let actDom, let actRet):
      let domType = try resolveSub(constraint,
        actType: actDom, actDesc: "signature domain",
        expType: expDom, expDesc: "signature domain")
      let retType = try resolveSub(constraint,
        actType: actRet, actDesc: "signature return",
        expType: expRet, expDesc: "signature return")
      return Type.Sig(dom: domType, ret: retType)

    default: throw Err(constraint, "actual type is not a signature")
    }
  }


  mutating func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String, expType: Type, expDesc: String) throws -> Type {
    let a = constraint.act
    let e = constraint.exp
    let sub = Constraint(
      act: Constraint.Side(expr: a.expr, type: actType, chain: .link(actDesc, a.chain)),
      exp: Constraint.Side(expr: e.expr, type: expType, chain: .link(expDesc, a.chain)),
      desc: constraint.desc)
    return try resolveConstraint(sub)
  }


  mutating func resolveSub(_ constraint: Constraint, actType: Type, actDesc: String) throws -> Type {
    let a = constraint.act
    let sub = Constraint(
      act: Constraint.Side(expr: a.expr, type: actType, chain: .link(actDesc, a.chain)),
      exp: constraint.exp,
      desc: constraint.desc)
    return try resolveConstraint(sub)
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


  mutating func resolve() {

    for constraint in constraints {
      do {
        _ = try resolveConstraint(constraint)
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
