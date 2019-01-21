// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Def: VaryingForm {

  case bind(Bind)
  case hostType(HostType)
  case in_(In)
  case method(Method)
  case polyfn(Polyfn)
  case pub(Pub)
  case typeAlias(TypeAlias)

  static func accept(_ actForm: ActForm) -> Def? {
    switch actForm {
    case let f as Bind:       return .bind(f)
    case let f as HostType:   return .hostType(f)
    case let f as In:         return .in_(f)
    case let f as Method:     return .method(f)
    case let f as Polyfn:     return .polyfn(f)
    case let f as Pub:        return .pub(f)
    case let f as TypeAlias:  return .typeAlias(f)
    default: return nil
    }
  }

 var actForm: ActForm {
    switch self {
    case .bind(let bind): return bind
    case .hostType(let hostType): return hostType
    case .in_(let in_): return in_
    case .method(let method): return method
    case .polyfn(let polyfn): return polyfn
    case .pub(let pub): return pub
    case .typeAlias(let typeAlias): return typeAlias
    }
  }

  static var expDesc: String { return "definition" }

  var sym: Sym {
    switch self {
    case .bind(let bind): return bind.place.sym
    case .hostType(let hostType): return hostType.sym
    case .in_(let in_): in_.fatal("`in` is not an individual definition; sym should never be called: \(in_).")
    case .method(let method): method.fatal("Extensions are not yet referenceable; sym should never be called: \(method).")
    case .polyfn(let polyfn): return polyfn.sym
    case .pub(let pub): return pub.def.sym
    case .typeAlias(let typeAlias): return typeAlias.sym
    }
  }


  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    switch self {

    case .bind(let bind):
      let localScope = LocalScope(parent: space)
      let (defCtx, val, type) = simplifyAndTypecheckVal(space: space, scope: localScope, ann: bind.place.ann, val: bind.val)
      let hostName = "\(space.hostPrefix)\(bind.place.sym.hostName)"
      let needsLazy = compileVal(defCtx: defCtx, hostName: hostName, val: val, type: type)
      if needsLazy {
        return .lazy(type)
      } else {
        return .val(type)
      }

    case .hostType:
      return .type(Type.Host(spacePathNames: space.pathNames, sym: sym))

    case .in_(let in_):
      in_.fatal("`in` is not an independent definition; compileDef should never be called: \(in_).")

    case .method(let method):
      method.fatal("Method is not an independent definition; compileDef should never be called: \(method).")

    case .polyfn(let polyfn):
      let localScope = LocalScope(parent: space)
      let prototype = Expr.sig(polyfn.sig).type(localScope, "polyfn signature")
      // Synthesize the default method if it should exist, then append any additional methods.
      var methods: Array<Method> = []
      if polyfn.body.isSyntacticallyPresent {
        let dfltMethod = Method(polyfn.syn, sym: polyfn.sym, sig: polyfn.sig, body: polyfn.body)
        methods.append(dfltMethod)
      }
      methods.append(contentsOf: space.methods[sym.name, default: []])
      // Typecheck each method.
      var typesToMethods: [Type:Method] = [:]
      var typesToMethodStatuses: [Type:PolyRecord.MethodStatus] = [:]
      for method in methods {
        let (defCtx, val, type) = simplifyAndTypecheckVal(space: space, scope: localScope, ann: nil, val: .fn(method.fn))
        guard case .sig = type.kind else { val.failType("method must be a function; resolved type: \(type)") }
        if let existing = typesToMethods[type] {
          polyfn.failType("polyfn has duplicate type: \(type)", notes:
            (existing, "conflicting method"),
            (method, "conflicting method"))
        }
        typesToMethods[type] = method
        // Since we do not know if any given method will get used, save each DefCtx and emit code lazily.
        typesToMethodStatuses[type] = .pending(defCtx: defCtx, val: val)
      }
      // TODO: verify that types do not intersect ambiguously.
      let polytype = Type.Poly(typesToMethodStatuses.keys.sorted())
      return .poly(PolyRecord(prototype: prototype, polytype: polytype, typesToMethodStatuses: typesToMethodStatuses))

    case .pub:
      fatalError("`pub` not yet implemented.")

    case .typeAlias(let typeAlias):
      return .type(typeAlias.expr.type(LocalScope(parent: space), "type alias"))
    }
  }
}


func simplifyAndTypecheckVal(space: Space, scope: LocalScope, ann: Ann?, val: Expr) -> (DefCtx, Expr, Type) {
  assert(scope.parent === space)
  let defCtx = DefCtx(globalCtx: space.ctx)
  let simplifiedVal = val.simplify(defCtx)
  let unresolvedType = defCtx.genConstraints(scope, expr: simplifiedVal, ann: ann)
  defCtx.typecheck()
  return (defCtx, simplifiedVal, defCtx.typeCtx.resolved(type: unresolvedType))
}


func compileVal(defCtx: DefCtx, hostName: String, val: Expr, type: Type) -> Bool {
  let em = Emitter(ctx: defCtx.globalCtx)
  if needsLazyDef(val: val) {
    let acc = "\(hostName)__acc"
    em.str(0, "let \(acc) = function() {")
    em.str(0, "  \(acc) = $lazy_sentinel;")
    em.str(0, "  const $v = // \(type)") // bling: $v: lazy value.
    val.compile(defCtx, em, 2, exp: type, isTail: false)
    em.append(";")
    em.str(0, "  \(acc) = function() { return $v };")
    em.str(0, "  return $v; }")
    em.flush()
    return true
  } else {
    em.str(0, "const \(hostName) = // \(type)")
    val.compile(defCtx, em, 0, exp: type, isTail: false)
    em.append(";")
    em.flush()
    return false
  }
}


func needsLazyDef(val: Expr) -> Bool {
  switch val {
  case .bind(let bind): return needsLazyDef(val: bind.val)
  case .fn, .hostVal, .litNum, .litStr: return false
  case .ann(let ann): return needsLazyDef(val: ann.expr)
  case .paren(let paren): return paren.els.any { needsLazyDef(val: $0) }
  // TODO: scope analysis of syms and paths?
  default: return true
  }
}
