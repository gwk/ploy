// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: ActFormBase, ActForm { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Body

  init(_ syn: Syn, sig: Sig, body: Body) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  static var expDesc: String { return "`fn`" }

  var textTreeChildren: [Any] { return [sig, body] }
}
