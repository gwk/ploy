// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: Form { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Body

  init(_ syn: Syn, sig: Sig, body: Body) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return [sig, body] }
}
