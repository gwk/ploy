// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


enum Def: SubForm {

  case bind(Bind)
  case hostType(HostType)
  case in_(In)
  case method(Method)
  case polyFn(PolyFn)
  case pub(Pub)

  init(form: Form, subj: String) {
    switch form {
    case let form as Bind:      self = .bind(form)
    case let form as HostType:  self = .hostType(form)
    case let form as In:        self = .in_(form)
    case let form as Method:    self = .method(form)
    case let form as PolyFn:    self = .polyFn(form)
    case let form as Pub:       self = .pub(form)
    default:
      form.failSyntax("\(subj) expects definition but received \(form.syntaxName).")
    }
  }

 var form: Form {
    switch self {
    case .bind(let bind): return bind
    case .hostType(let hostType): return hostType
    case .in_(let in_): return in_
    case .method(let method): return method
    case .polyFn(let polyFn): return polyFn
    case .pub(let pub): return pub
    }
  }

  var sym: Sym {
    switch self {
    case .bind(let bind): return bind.place.sym
    case .hostType(let hostType): return hostType.sym
    case .in_: fatalError("INTERNAL ERROR: In is not an individual definition; sym should never be called.")
    case .method: fatalError("INTERNAL ERROR: Method is not an independent definition; sym should never be called.")
    case .polyFn(let polyFn): return polyFn.sym
    case .pub(let pub): return pub.def.sym
    }
  }

  func compileDef(_ space: Space) -> ScopeRecord.Kind {
    switch self {

    case .bind(let bind):
      return compileBindingVal(space: space, sym: bind.place.sym, val: bind.val, suffix: "")

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
      for (sigType, pair) in sigsToPairs.pairsSortedByKey {
        pair.method.compileMethod(space, polyFnType: type, sigType: sigType, hostName: hostName)
      }
      em.append("}")
      em.str(0, "function \(hostName)($){")
      em.str(0, "  throw \"INTERNAL ERROR: PolyFn dispatch not implemented\"") // TODO: dispatch.
      em.append("}")
      em.flush()
      return .polyFn(type)

    case .pub:
      fatalError()
    }
  }
}


func compileBindingVal(space: Space, sym: Sym, val: Expr, suffix: String) -> ScopeRecord.Kind {
  let ctx = TypeCtx()
  let _ = val.genTypeConstraints(ctx, LocalScope(parent: space)) // initial root type is ignored.
  ctx.resolve()
  let type = ctx.typeFor(expr: val)
  let em = Emitter(file: space.file)
  //let fullName = "\(space.name)/\(sym.name)"
  let hostName = "\(space.hostPrefix)\(sym.hostName)"
  let isMain = (hostName == "MAIN__main")
  if val.needsLazyDef && !isMain {
    let acc = "\(hostName)__acc"
    em.str(0, "var \(acc) = function() {")
    em.str(0, " \(acc) = $lazy_sentinal;")
    em.str(0, " let val =")
    val.compile(ctx, em, 1, isTail: false)
    em.append(";")
    em.str(0, " \(acc) = function() { return val };")
    em.str(0, " return val; }")
    em.flush()
    return .lazy(type)
  } else {
    em.str(0, "let \(hostName) =")
    val.compile(ctx, em, 1, isTail: false)
    em.append(";")
    em.flush()
    return .val(type)
  }
}
