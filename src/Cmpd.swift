// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Cmpd: Form { // compound value: `(a b)`.
  let fields: [Expr]

  init(_ syn: Syn, fields: [Expr]) {
    self.fields = fields
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, fields.isEmpty ? " ()\n" : "\n")
    for a in fields {
      a.write(to: &stream, depth + 1)
    }
  }

  // MARK: Cmpd

  func compilePar(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, par: TypePar, argIndex: inout Int) {
    if argIndex < fields.count {
      let arg = fields[argIndex]
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
