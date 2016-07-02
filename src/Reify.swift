// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Reify: _Form { // type reification:  `T^A`.
  let callee: TypeExpr
  let arg: TypeExpr

  required init(_ syn: Syn, callee: TypeExpr, arg: TypeExpr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      callee: TypeExpr(form: l, subj: "type reification"),
      arg: TypeExpr(form: r, subj: "type reification"))
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    callee.write(to: &stream, depth + 1)
    arg.write(to: &stream, depth + 1)
  }
}


/// type reification implied by adjacency to CmpdType: `T<A B>`.
class ReifyAdj: Reify {}

