// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Def: SubForm {

  case bind(Bind)
  case ext(Extension)
  case extensible(Extensible)
  case hostType(HostType)
  case in_(In)
  case pub(Pub)
  case typeAlias(TypeAlias)

  init?(form: Form) {
    switch form {
    case let f as Bind:       self = .bind(f)
    case let f as Extension:  self = .ext(f)
    case let f as Extensible: self = .extensible(f)
    case let f as HostType:   self = .hostType(f)
    case let f as In:         self = .in_(f)
    case let f as Pub:        self = .pub(f)
    case let f as TypeAlias:  self = .typeAlias(f)
    default: return nil
    }
  }

 var form: Form {
    switch self {
    case .bind(let bind): return bind
    case .ext(let ext): return ext
    case .extensible(let extensible): return extensible
    case .hostType(let hostType): return hostType
    case .in_(let in_): return in_
    case .pub(let pub): return pub
    case .typeAlias(let typeAlias): return typeAlias
    }
  }

  static var parseExpDesc: String { return "definition" }

  var sym: Sym {
    switch self {
    case .bind(let bind): return bind.place.sym
    case .ext(let ext): ext.fatal("Extensions are not yet referenceable; sym should never be called: \(ext).")
    case .extensible(let extensible): return extensible.sym
    case .hostType(let hostType): return hostType.sym
    case .in_(let in_): in_.fatal("`in` is not an individual definition; sym should never be called: \(in_).")
    case .pub(let pub): return pub.def.sym
    case .typeAlias(let typeAlias): return typeAlias.sym
    }
  }


  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    switch self {

    case .bind(let bind):
      let (defCtx, val, type) = simplifyAndTypecheckVal(space: space, place: bind.place, val: bind.val)
      let hostName = "\(space.hostPrefix)\(bind.place.sym.hostName)"
      let needsLazy = compileVal(defCtx: defCtx, hostName: hostName, val: val, type: type)
      if needsLazy {
        return .lazy(type)
      } else {
        return .val(type)
      }

    case .ext(let ext):
      ext.fatal("Extension is not an independent definition; compileDef should never be called: \(ext).")

    case .extensible(let extensible):
      let exts = space.exts[sym.name, default: []]
      var typesToExts: [Type:Extension] = [:]
      var typesToMorphs: [Type:Morph] = [:]
      for ext in exts {
        let (defCtx, val, type) = simplifyAndTypecheckVal(space: space, place: ext.place, val: ext.val)
        guard case .sig = type.kind else { val.form.failType("morph must be a function; resolved type: \(type)") }
        if let existing = typesToExts[type] {
          extensible.failType("extensible has duplicate type: \(type)", notes:
            (existing, "conflicting extension"),
            (ext, "conflicting extension"))
        }
        typesToExts[type] = ext
        // Since we do not know if any given morph will get used, save each DefCtx and emit code lazily.
        typesToMorphs[type] = Morph(defCtx: defCtx, val: val, type: type)
      }
      // TODO: verify that types do not intersect ambiguously.
      let hostName = "\(space.hostPrefix)\(extensible.sym.hostName)"
      let type = Type.Poly(typesToMorphs.keys.sorted())
      return .poly(PolyRecord(sym: sym, hostName: hostName, type: type, typesToMorphs: typesToMorphs))

    case .hostType:
      return .type(Type.Host(spacePathNames: space.pathNames, sym: sym))

    case .in_(let in_):
      in_.fatal("`in` is not an independent definition; compileDef should never be called: \(in_).")

    case .pub:
      fatalError()

    case .typeAlias(let typeAlias):
      return .type(typeAlias.expr.type(space, "type alias"))
    }
  }
}


func simplifyAndTypecheckVal(space: Space, place: Place, val: Expr) -> (DefCtx, Expr, Type) {
  let defCtx = DefCtx(globalCtx: space.ctx)
  let simplifiedVal = val.simplify(defCtx)
  let unresolvedType = defCtx.genConstraints(LocalScope(parent: space), expr: simplifiedVal, ann: place.ann)
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
  default: return true
  }
}
