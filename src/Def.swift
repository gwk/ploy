// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


enum Def: SubForm {

  case bind(Bind)
  case enum_(Enum)
  case hostType(HostType)
  case in_(In)
  case method(Method)
  case polyFn(PolyFn)
  case pub(Pub)
  case struct_(Struct)

  init(form: Form, subj: String) {
    if let form = form as? Bind           { self = .bind(form) }
    else if let form = form as? Enum      { self = .enum_(form) }
    else if let form = form as? HostType  { self = .hostType(form) }
    else if let form = form as? In        { self = .in_(form) }
    else if let form = form as? Method    { self = .method(form) }
    else if let form = form as? PolyFn    { self = .polyFn(form) }
    else if let form = form as? Pub       { self = .pub(form) }
    else if let form = form as? Struct    { self = .struct_(form) }
    else {
      form.failSyntax("\(subj) expects definition but received \(form.syntaxName).")
    }
  }

 var form: Form {
    switch self {
    case .bind(let bind): return bind
    case .enum_(let enum_): return enum_
    case .hostType(let hostType): return hostType
    case .in_(let in_): return in_
    case .method(let method): return method
    case .polyFn(let polyFn): return polyFn
    case .pub(let pub): return pub
    case .struct_(let struct_): return struct_
    }
  }

  var sym: Sym {
    switch self {
    case .bind(let bind): return bind.place.sym
    case .enum_(let enum_): return enum_.sym
    case .hostType(let hostType): return hostType.sym
    case .in_: fatalError("INTERNAL ERROR: In is not an individual definition; sym should never be called.")
    case .method: fatalError("INTERNAL ERROR: Method is not an independent definition; sym should never be called.")
    case .polyFn(let polyFn): return polyFn.sym
    case .pub(let pub): return pub.def.sym
    case .struct_(let struct_): return struct_.sym
    }
  }

  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    switch self {

    case .bind(let bind):
      let ctx = TypeCtx()
      let _ = bind.val.genTypeConstraints(ctx, LocalScope(parent: space)) // initial root type is ignored.
      ctx.resolve()
      let type = ctx.typeFor(expr: bind.val)
      let em = Emitter(file: space.file)
      //let fullName = "\(space.name)/\(sym.name)"
      let hostName = "\(space.hostPrefix)\(sym.hostName)"
      if bind.val.needsLazyDef {
        let acc = "\(hostName)__acc"
        em.str(0, "var \(acc) = function() {")
        em.str(0, " \(acc) = _lazy_sentinal;")
        em.str(0, " let val =")
        bind.val.compile(ctx, em, 1, isTail: false)
        em.append(";")
        em.str(0, " \(acc) = function() { return val };")
        em.str(0, " return val; }")
        em.flush()
        return .lazy(type)
      } else {
        em.str(0, "let \(hostName) =")
        bind.val.compile(ctx, em, 1, isTail: false)
        em.append(";")
        em.flush()
        return .val(type)
      }

    case .enum_:
      // TODO.
      return .type(Type.Enum(spacePathNames: space.pathNames, sym: sym))

    case .hostType:
      return .type(Type.Host(spacePathNames: space.pathNames, sym: sym))

    case .in_:
      fatalError("INTERNAL ERROR: In is not an independent definition; compileDef should never be called.")

    case .method:
      fatalError("INTERNAL ERROR: Method is not an independent definition; compileDef should never be called.")

    case .polyFn(let polyFn):
      let hostName = "\(space.hostPrefix)\(sym.name)"
      let methodList = space.methods.getDefault(sym.name)
      var sigsToPairs: [Type: MethodList.Pair]
      do {
        sigsToPairs = try methodList.pairs.mapUniquesToDict() {
          (pair) in
          (pair.method.typeForMethodSig(pair.space), pair)
        }
      } catch let e as DuplicateKeyError<Type, MethodList.Pair> {
        polyFn.failType("method has duplicate type: \(e.key)", notes:
          (e.existing.method, "conflicting method definition"),
          (e.incoming.method, "conflicting method definition"))
      } catch { fatalError() }
      let type = Type.All(Set(sigsToPairs.keys))
      let em = Emitter(file: space.file)
      em.str(0, "\(hostName)__table = {")
      for (sig, pair) in sigsToPairs.pairsSortedByKey {
        pair.method.compileMethod(space, polyFnType: type, sigType: sig, hostName: hostName)
      }
      em.append("}")
      em.str(0, "function \(hostName)($){")
      em.str(0, "  throw \"INTERNAL ERROR: PolyFn dispatch not implemented\"") // TODO: dispatch.
      em.append("}")
      em.flush()
      return .polyFn(type)

    case .pub:
      fatalError()

    case .struct_:
      // TODO.
      return .type(Type.Struct(spacePathNames: space.pathNames, sym: sym))
    }
  }
}
