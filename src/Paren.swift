// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Paren: Form { // parenthesized expression: `(a b)`.
  let els: [Expr]

  init(_ syn: Syn, els: [Expr]) {
    self.els = els
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, els.isEmpty ? " ()\n" : "\n")
    for a in els {
      a.write(to: &stream, depth + 1)
    }
  }

  // MARK: Cmpd

  var isTrivial: Bool {
    return els.count == 1 && els[0].label == nil
  }

  func compilePar(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, par: TypePar, argIndex: inout Int) {
    if argIndex < els.count {
      let arg = els[argIndex]
      if let argLabel = arg.label {
        if let parLabel = par.label {
          if argLabel.name != parLabel.name {
            argLabel.failType("argument label does not match parameter label", notes: (parLabel, "parameter label"))
          }
        } else {
          argLabel.failType("argument label does not match unlabeled parameter", notes: (arg.form, "unlabeled parameter"))
        }
      }
      em.str(depth, " \(par.hostName):")
      arg.compile(ctx, em, depth + 1, isTail: false)
      em.append(",")
      argIndex += 1
    } else { // TODO: support default arguments.
      failType("missing argument for parameter")
    }
  }
}
