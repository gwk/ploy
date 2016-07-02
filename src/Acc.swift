// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Acc: _Form { // accessor: `field@val`.
  let accessor: Accessor
  let accessee: Expr
  
  init(_ syn: Syn, accessor: Accessor, accessee: Expr) {
    self.accessor = accessor
    self.accessee = accessee
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Acc(Syn(l.syn, r.syn),
      accessor: Accessor(form: l, subj: "access"),
      accessee: Expr(form: r, subj: "access", exp: "accessee expression"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    accessor.form.write(to: &stream, depth + 1)
    accessee.form.write(to: &stream, depth + 1)
  }
}

