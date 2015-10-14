// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class In: _Form { // in statement: `in module-name statements…;`.
  let identifier: Identifier
  let defs: [Def]

  init(_ syn: Syn, identifier: Identifier, defs: [Def]) {
    self.identifier = identifier
    self.defs = defs
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    identifier.writeTo(&target, depth + 1)
    for d in defs {
      d.writeTo(&target, depth + 1)
    }
  }
}
