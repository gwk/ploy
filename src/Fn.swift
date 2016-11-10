// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: Form { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Expr

  init(_ syn: Syn, sig: Sig, body: Expr) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Fn(Syn(l.syn, r.syn),
      sig: castForm(l, "function left side", "function parameter signature"),
      body: Expr(form: r, subj: "function body"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sig.write(to: &stream, depth + 1)
    body.write(to: &stream, depth + 1)
  }
}
