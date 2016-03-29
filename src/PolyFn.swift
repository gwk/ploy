// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class PolyFn: _Form, Def {
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
  }

  // MARK: Def

  func compileDef(space: Space) -> ScopeRecord.Kind {
    let hostName = "\(space.hostPrefix)\(sym.name)"
    let methodList = space.methods.getDefault(sym.name)
    var sigsToPairs: [Type: MethodList.Pair]
    do {
      sigsToPairs = try methodList.pairs.mapUniquesToDict() {
        (pair) in
        (pair.method.typeForMethodSig(pair.space), pair)
      }
    } catch let e as DuplicateKeyError<Type, MethodList.Pair> {
      failType("method has duplicate type: \(e.key)", notes:
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
    em.str(0, " throw \"error: PolyFn dispatch not implemented\"") // TODO: dispatch.
    em.append("}")
    em.flush()
    return .PolyFn(type)
  }
}
