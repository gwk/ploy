// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class SymPath: ActFormBase, ActForm { // path: `LIB/name`.
  let syms: [Sym]

  init(_ syn: Syn, syms: [Sym]) {
    assert(syms.count > 0)
    self.syms = syms
    super.init(syn)
  }

  override var description: String {
    var desc = "\(type(of: self)):\(syn): "
    var first = true
    for s in syms {
      if first {
        first = false
      } else {
        desc.append("/")
      }
      desc.append(s.name)
    }
    return desc
  }

  static var expDesc: String { return "symbol path" }

  var textTreeChildren: [Any] { return [] }
}
