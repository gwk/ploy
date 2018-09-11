// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Polyfn: ActFormBase, ActForm {
  let sym: Sym
  let sig: Sig

  init(_ syn: Syn, sym: Sym, sig: Sig) {
    self.sym = sym
    self.sig = sig
    super.init(syn)
  }

  static var expDesc: String { return "`polyfn`" }

  var textTreeChildren: [Any] { return [sym, sig] }
}
