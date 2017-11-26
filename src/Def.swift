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
      let (type, needsLazy) = compileBindingVal(space: space, place: bind.place, val: bind.val, addTypeSuffix: false)
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
      var typesToNeedsLazy: [Type:Bool] = [:]
      for ext in exts {
        // TODO: this is problematic because we emit all extensions as soon as the extensible is referenced.
        // However, lazy emission is more complicated.
        let (type, needsLazy) = compileBindingVal(space: space, place: ext.place, val: ext.val, addTypeSuffix: true)
        if let existing = typesToExts[type] {
          extensible.failType("extensible has duplicate type: \(type)", notes:
            (existing, "conflicting extension"),
            (ext, "conflicting extension"))
        }
        typesToExts[type] = ext
        typesToNeedsLazy[type] = needsLazy
      }
      // TODO: verify that types do not intersect ambiguously.
      let type = Type.Poly(typesToNeedsLazy.keys.sorted())
      #if false
      let em = Emitter(ctx: space.ctx)
      let hostName = "\(space.hostPrefix)\(sym.hostName)"
      em.str(0, "const \(hostName)__$table = {")
      // TODO: emit table contents.
      em.append("}")
      em.str(0, "function \(hostName)($){")
      em.str(0, "  throw new Error('PLOY RUNTIME ERROR: extensible dispatch not implemented')") // TODO: dispatch.
      em.append("}")
      em.flush()
      #endif
      return .poly(type, morphsToNeedsLazy: typesToNeedsLazy)

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


func compileBindingVal(space: Space, place: Place, val: Expr, addTypeSuffix: Bool) -> (Type, needsLazy: Bool) {
  let defCtx = DefCtx(globalCtx: space.ctx)
  let val = val.simplify(defCtx)
  let unresolvedType = defCtx.genConstraints(LocalScope(parent: space), expr: val, ann: place.ann)
  defCtx.typecheck()
  let type = defCtx.typeCtx.resolved(type: unresolvedType)
  let suffix = (addTypeSuffix ? "__\(type.globalIndex)" : "")
  let em = Emitter(ctx: space.ctx)
  //let fullName = "\(space.name)/\(place.sym.name)"
  let hostName = "\(space.hostPrefix)\(place.sym.hostName)\(suffix)"
  if needsLazyDef(val: val, type: type) {
    let acc = "\(hostName)__acc"
    em.str(0, "let \(acc) = function() {")
    em.str(0, "  \(acc) = $lazy_sentinel;")
    em.str(0, "  const $v = // \(type)") // bling: $v: lazy value.
    val.compile(defCtx, em, 2, exp: type, isTail: false)
    em.append(";")
    em.str(0, "  \(acc) = function() { return $v };")
    em.str(0, "  return $v; }")
    em.flush()
    return (type, needsLazy: true)
  } else {
    em.str(0, "const \(hostName) = // \(type)")
    val.compile(defCtx, em, 0, exp: type, isTail: false)
    em.append(";")
    em.flush()
    return (type, needsLazy: false)
  }
}


func needsLazyDef(val: Expr, type: Type) -> Bool {
  switch val {
  case .fn, .hostVal, .litNum, .litStr: return false
  case .ann(let ann): return needsLazyDef(val: ann.expr, type: type)
  case .paren(let paren):
    if paren.isScalarValue {
      return needsLazyDef(val: paren.els[0], type: type)
    } else {
      return hasLazyMember(paren: paren, type: type)
    }
  case .sym:
    switch type.kind {
    case .sig: return false
    default: return true
    }
  default: return true
  }
}


func hasLazyMember(paren: Paren, type: Type) -> Bool {
  guard case .struct_(let fields, let variants) = type.kind else { fatalError() }
  var i = 0
  for typeField in fields {
    if needsLazyDef(val: paren.els[i], type: typeField.type) { return true }
    i += 1
  }
  if variants.isEmpty {
    assert(i == paren.els.count)
    return false
  } else {
    assert(variants.count == 1)
    assert(i == paren.els.lastIndex)
    return needsLazyDef(val: paren.els[i], type: variants[0].type)
  }
}
