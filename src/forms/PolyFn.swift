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

  func scopeRecordKind(space: Space) -> ScopeRecord.Kind {
    fatalError()
  }

  func compileDef(space: Space) -> ScopeRecord.Kind {
    let methodList = space.methods.getDefault(sym.name, dflt: { MethodList() })
    let sigs = methodList.pairs.enumerate().map() {
      $1.method.compileMethod($1.space, expType: typeAnySig, hostName: "\(space.hostPrefix)\(sym.name)__\($0)")
    }
    return .PolyFn(PolyFnRecord(sigs: sigs))
  }

}
