// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: Form { // function signature: `Par->Ret`.
  let send: Expr
  let ret: Expr

  init(_ syn: Syn, send: Expr, ret: Expr) {
    self.send = send
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Sig(Syn(l.syn, r.syn),
      send: Expr(form: l, subj: "signature send"),
      ret: Expr(form: r, subj: "signature return"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    send.write(to: &stream, depth + 1)
    ret.write(to: &stream, depth + 1)
  }
}

