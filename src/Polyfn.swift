// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Polyfn: ActFormBase, ActForm {
  let sym: Sym
  let sig: Sig
  let body: Body

  init(_ syn: Syn, sym: Sym, sig: Sig, body: Body) {
    self.sym = sym
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  static var expDesc: String { return "`polyfn`" }

  var textTreeChildren: [Any] { return [sym, sig, body] }
}
