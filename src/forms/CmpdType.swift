// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


class CmpdType: _Form, TypeExpr { // compound type: `<A B>`.
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
}


