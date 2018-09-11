// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Method: ActFormBase, ActForm {
  let sym: Sym
  let fn: Fn

  init(_ syn: Syn, sym: Sym, sig: Sig, body: Body) {
    self.sym = sym
    self.fn = Fn(syn, sig: sig, body: body)
    // Note: we synthesize a function here so it has the same lifetime as the Method.
    // It is unknown at this time as to whether a computed `fn` var would also work.
    super.init(syn)
  }

  static var expDesc: String { return "`method`" }

  var textTreeChildren: [Any] { return [sym, fn] }
}
