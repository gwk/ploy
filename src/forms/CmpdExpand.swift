// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class CmpdExpand: _Form { // compound macro expansion argument: `[a b]`.
  let pars: [Par]

  init(_ syn: Syn, pars: [Par]) {
    self.pars = pars
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for p in pars {
      p.writeTo(&target, depth + 1)
    }
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
  }
}

