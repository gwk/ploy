// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: _Form { // function signature: `Par%Ret`.
  let par: TypeExpr // TODO: rename input.
  let ret: TypeExpr

  init(_ syn: Syn, par: TypeExpr, ret: TypeExpr) {
    self.par = par
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Sig(Syn(l.syn, r.syn),
      par: TypeExpr(form: l, subj: "signature parameter"),
      ret: TypeExpr(form: r, subj: "signature return"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    par.write(to: &stream, depth + 1)
    ret.write(to: &stream, depth + 1)
  }
}

