// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Def: SubForm {

  case bind(Bind)
  case ext(Extension)
  case extensible(Extensible)
  case hostType(HostType)
  case in_(In)
  case pub(Pub)

  init(form: Form, subj: String) {
    switch form {
    case let form as Bind:        self = .bind(form)
    case let form as Extension:   self = .ext(form)
    case let form as Extensible:  self = .extensible(form)
    case let form as HostType:    self = .hostType(form)
    case let form as In:          self = .in_(form)
    case let form as Pub:         self = .pub(form)
    default:
      form.failSyntax("\(subj) expects definition but received \(form.syntaxName).")
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
    }
  }

  var sym: Sym {
    switch self {
    case .bind(let bind): return bind.place.sym
    case .ext(let ext): form.fatal("Extensions are not yet referenceable; sym should never be called: \(ext).")
    case .extensible(let extensible): return extensible.sym
    case .hostType(let hostType): return hostType.sym
    case .in_(let in_): form.fatal("`in` is not an individual definition; sym should never be called: \(in_).")
    case .pub(let pub): return pub.def.sym
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
      form.fatal("Extension is not an independent definition; compileDef should never be called: \(ext).")

    case .extensible(let extensible):
      let exts = space.exts.getDefault(sym.name, dflt: Ref<[Extension]>()).val
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
      let type = Type.Poly(Set(typesToNeedsLazy.keys))
      let em = Emitter(file: space.ctx.file)
      let hostName = "\(space.hostPrefix)\(sym.hostName)"
      em.str(0, "let \(hostName)__$table = {")
      // TODO: emit table contents.
      em.append("}")
      em.str(0, "function \(hostName)($){")
      em.str(0, "  throw \"INTERNAL RUNTIME ERROR: extensible dispatch not implemented\"") // TODO: dispatch.
      em.append("}")
      em.flush()
      return .poly(type, morphsToNeedsLazy: typesToNeedsLazy)

    case .hostType:
      return .type(Type.Host(spacePathNames: space.pathNames, sym: sym))

    case .in_(let in_):
      form.fatal("`in` is not an independent definition; compileDef should never be called: \(in_).")

    case .pub:
      fatalError()
    }
  }
}


func compileBindingVal(space: Space, place: Place, val: Expr, addTypeSuffix: Bool) -> (Type, needsLazy: Bool) {
  var ctx = TypeCtx(globalCtx: space.ctx)
  _ = ctx.genConstraints(LocalScope(parent: space), expr: val) // initial root type is ignored.
  if let ann = place.ann {
    _ = ctx.constrainAnn(space, expr: val, ann: ann)
  }
  ctx.resolve()
  let type = ctx.typeFor(expr: val)
  let suffix = (addTypeSuffix ? "__\(type.globalIndex)" : "")
  let em = Emitter(file: space.ctx.file)
  //let fullName = "\(space.name)/\(place.sym.name)"
  let hostName = "\(space.hostPrefix)\(place.sym.hostName)\(suffix)"
  if val.needsLazyDef {
    let acc = "\(hostName)__acc"
    em.str(0, "var \(acc) = function() {")
    em.str(0, " \(acc) = $lazy_sentinal;")
    em.str(0, " let val = // \(type)")
    val.compile(&ctx, em, 1, isTail: false)
    em.append(";")
    em.str(0, " \(acc) = function() { return val };")
    em.str(0, " return val; }")
    em.flush()
    return (type, needsLazy: true)
  } else {
    em.str(0, "let \(hostName) = // \(type)")
    val.compile(&ctx, em, 1, isTail: false)
    em.append(";")
    em.flush()
    return (type, needsLazy: false)
  }
}
