// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Reify: Form { // type reification:  `T^A`.
  let callee: Expr
  let arg: Expr

  required init(_ syn: Syn, callee: Expr, arg: Expr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      callee: Expr(form: l, subj: "type reification"),
      arg: Expr(form: r, subj: "type reification"))
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    callee.write(to: &stream, depth + 1)
    arg.write(to: &stream, depth + 1)
  }
}


/// type reification implied by adjacency to CmpdType: `T<A B>`.
class ReifyAdj: Reify {}
