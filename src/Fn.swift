// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: Form { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Do

  init(_ syn: Syn, sig: Sig, body: Do) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sig.write(to: &stream, depth + 1)
    body.write(to: &stream, depth + 1)
  }
}
