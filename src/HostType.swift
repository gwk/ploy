// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostType: ActFormBase, ActForm { // host type declaration: `host_type sym;`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  static var expDesc: String { return "`host_type`" }

  var textTreeChildren: [Any] { return [sym] }
}
