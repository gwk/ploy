// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


struct Constraint {
  let actExpr: Expr
  let actType: Type
  let actChain: Chain<String>
  let expForm: Form
  let expType: Type
  let expChain: Chain<String>
  let desc: String

  var actDesc: String { return actChain.map({"\($0) of\n"}).join() }
  var expDesc: String { return expChain.map({"\($0) of\n"}).join() }

  func subConstraint(actType: Type, actDesc: String?, expType: Type, expDesc: String?) -> Constraint {
    return Constraint(
      actExpr: actExpr, actType: actType, actChain: (actDesc == nil) ? actChain : .link(actDesc!, actChain),
      expForm: expForm, expType: expType, expChain: (expDesc == nil) ? expChain : .link(expDesc!, expChain), desc: desc)
  }

  @noreturn
  func fail(act: Type, exp: Type, _ msg: String) {
    actExpr.form.failType(
      "\(msg);\n\(actDesc)\(desc);\nresolved type: \(act)",
      notes: (expForm, "\n\(expDesc)\(desc);\nexpected type: \(exp)"))
  }
}


class TypeCtx {

  struct Error: ErrorProtocol {
    let constraint: Constraint
    let msg: String

    init(_ constraint: Constraint, _ msg: String) {
      self.constraint = constraint
      self.msg = msg
    }
  }

  private var constraints: [Constraint] = []
  private var freeTypes: [Type] = []
  private var resolvedTypes: [Type:Type] = [:] // maps all types containing free types to partially or completely resolved types.
  private var freeIndicesToUnresolvedTypes: DictOfSet<Int, Type> = [:] // maps free types to all types containing them.
  private var exprOriginalTypes = [Form:Type]() // maps forms to original types.
  private var isResolved = false

  var symRecords = [Sym:ScopeRecord]()
  var pathRecords = [Path:ScopeRecord]()

  deinit { assert(isResolved) }

  func assertIsTracking(_ expr: Expr) { assert(exprOriginalTypes.contains(key: expr.form)) }

  func originalTypeForExpr(_ expr: Expr) -> Type { return exprOriginalTypes[expr.form]! }

  func resolvedType(_ type: Type) -> Type {
    return resolvedTypes[type].or(type)
  }

  func typeForExpr(_ expr: Expr) -> Type {
    return resolvedType(originalTypeForExpr(expr))
  }

  func addFreeType() -> Type {
    let t = Type.Free(freeTypes.count)
    freeTypes.append(t)
    return t
  }

  func trackExpr(_ expr: Expr, type: Type) {
    exprOriginalTypes.insertNew(expr.form, value: type)
    trackFreeTypes(type)
  }

  func trackFreeTypes(_ type: Type) {
    for free in type.frees {
      guard case .free(let index) = free.kind else { fatalError() }
      freeIndicesToUnresolvedTypes.insert(index, member: type)
    }
  }

  func constrain(_ actExpr: Expr, expForm: Form, expType: Type, _ desc: String) {
    trackFreeTypes(expType)
    constraints.append(Constraint(
      actExpr: actExpr, actType: originalTypeForExpr(actExpr), actChain: .end,
      expForm: expForm, expType: expType, expChain: .end, desc: desc))
  }

  func resolveType(_ type: Type, to resolved: Type) {
    if let existing = resolvedTypes[type] {
      fatalError("multiple resolutions not yet supported;\n  original: \(type)\n  existing: \(existing)\n  incoming: \(resolved)")
    }
    resolvedTypes[type] = resolved
    if case .free(let index) = resolved.kind {
      let unresolvedTypes = (freeIndicesToUnresolvedTypes[index]?.val).or([])
      for el in unresolvedTypes {
        let elResolved = el.refine(type, with: resolved)
        resolveType(el, to: elResolved)
      }
      _ = freeIndicesToUnresolvedTypes.removeValue(index)
    }
  }

  func resolveFreeType(_ freeType: Type, to resolved: Type) {
    // just for clarity / as an experiment, always prefer lower free indices.
    if case .free(let resolvedIndex) = resolved.kind {
      if freeType.freeIndex > resolvedIndex {
        resolveType(freeType, to: resolved)
      } else {
        resolveType(resolved, to: freeType)
      }
    }
  }

  func resolveOpaqueConstraint(_ constraint: Constraint, actType: Type, expOpaqueType: Type) {
    switch actType.kind {
    case .prop(let accessor, let accesseeType):
      switch accesseeType.kind {
      case .cmpd(let pars, _, _):
        for par in pars {
          if par.accessorString == accessor.accessorString {
            resolveConstraint(constraint.subConstraint(
              actType: par.type, actDesc: "`\(par.accessorString)` property",
              expType: expOpaqueType, expDesc: nil))
            return
          }
        }
      default: constraint.fail(act: accesseeType, exp: expOpaqueType, "actual type is not an accessible type")
      }
    default: constraint.fail(act: actType, exp: expOpaqueType, "actual type is not expected opaque type")
    }
    fatalError()
  }

  func resolveConstraint(_ constraint: Constraint) {
    let actType = resolvedType(constraint.actType)
    let expType = resolvedType(constraint.expType)
    if (actType == expType) {
      return
    }
    // first eleminate the case where actType is free.
    if case .free = actType.kind {
      resolveFreeType(actType, to: expType)
      return
    }

    switch expType.kind {
    case .all(_, _, _):
      constraint.fail(act: actType, exp: expType, "expected type of kind `All` not yet implemented")
    case .any(let members, _, _):
      if members.contains(actType) { return }
      constraint.fail(act: actType, exp: expType, "actual type is not a member of `Any` expected type")
    case .cmpd(_ , _, _):
      switch actType.kind {
      case .cmpd(_, _, _):
        constraint.fail(act: actType, exp: expType, "Cmpd type conversion not implemented")
      default: constraint.fail(act: actType, exp: expType, "actual type is not a compound")
      }
    case .enum_:
      constraint.fail(act: actType, exp: expType, "enum constraints not implemented")
    case .free:
      resolveType(expType, to: actType)
      return
    case .host, .prim:
      resolveOpaqueConstraint(constraint, actType: actType, expOpaqueType: expType)
      return
    case .prop(_, _):
      constraint.fail(act: actType, exp: expType, "prop constraints not implemented")
    case .sig(let expPar, let expRet, _, _):
      switch actType.kind {
      case .sig(let actPar, let actRet, _, _):
        resolveConstraint(constraint.subConstraint(
          actType: actPar, actDesc: "signature parameter",
          expType: expPar, expDesc: "signature parameter"))
        resolveConstraint(constraint.subConstraint(
          actType: actRet, actDesc: "signature return",
          expType: expRet, expDesc: "signature return"))
        return
      default: constraint.fail(act: actType, exp: expType, "actual type is not a signature")
      }
    case .struct_:
      constraint.fail(act: actType, exp: expType, "struct constraints not implemented")
    case .var_:
      constraint.fail(act: actType, exp: expType, "var constraints not implemented")
    }
    fatalError()
  }

  func resolve() {

    for constraint in constraints {
      resolveConstraint(constraint)
    }

    // check that resolution is complete.
    for type in freeTypes {
      guard let resolved = resolvedTypes[type] else {
        fatalError("unresolved free type: \(type)")
      }
      if case .free = resolved.kind {
        fatalError("free type resolved to free type: \(type) -> \(resolved)")
      }
    }
    for (index, set) in freeIndicesToUnresolvedTypes {
      for type in set.val {
        errL("freeIndicesToUnResolvedType: \(index): \(type)")
      }
    }
    check(freeIndicesToUnresolvedTypes.isEmpty)
    isResolved = true
  }
}

