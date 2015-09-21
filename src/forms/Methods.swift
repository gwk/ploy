// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Methods: _Form { // multiple methods definition.
  let identifier: Identifier
  let fns: [Expr]
  
  init(_ syn: Syn, identifier: Identifier, fns: [Expr]) {
    self.identifier = identifier
    self.fns = fns
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    identifier.writeTo(&target, depth + 1)
    for f in fns {
      f.writeTo(&target, depth + 1)
    }
  }
}
