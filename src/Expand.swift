// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Expand: Form { // compound macro expansion argument: `[a b]`.
  let pars: [Expr]

  init(_ syn: Syn, pars: [Expr]) {
    self.pars = pars
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    for p in pars {
      p.write(to: &stream, depth + 1)
    }
  }

  func compileExpand(depth: Int, _ scope: LocalScope) -> Type {
    fatalError()
  }
}

