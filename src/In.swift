// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class In: ActFormBase, ActForm { // in statement: `in module-name statements…;`.
  let identifier: Identifier? // main In does not have an identifier.
  let defs: [Def]

  init(_ syn: Syn, identifier: Identifier?, defs: [Def]) {
    self.identifier = identifier
    self.defs = defs
    super.init(syn)
  }

  static var expDesc: String { return "`in`" }

  var textTreeChildren: [Any] {
    var children = [Any]()
    children.appendOpt(identifier)
    children.append(defs)
    return children
  }
}
