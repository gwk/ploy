// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Cmpd: _Form, Expr { // compound value: `(a b)`.
  let args: [Arg]
  
  init(_ syn: Syn, args: [Arg]) {
    self.args = args
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for a in args {
      a.writeTo(&target, depth + 1)
    }
  }
  
  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let pars = args.enumerate().map { $1.typeParForArg(ctx, scope, index: $0) }
    return Type.Cmpd(pars)
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    let type = ctx.typeForForm(self)
    em.str(depth, isTail ? "{{v:" : "{")
    switch type.kind {
    case .Cmpd(let pars, _, _):
      var argIndex = 0
      for par in pars {
        self.compilePar(ctx, scope, depth, par: par, argIndex: &argIndex)
      }
      if argIndex != pars.count {
        failType("expected \(pars.count) arguments; received \(argIndex)")
      }
    default:
      self.failType("expected type: \(type); received compound value.")
    }
    em.append(isTail ? "}}" : "}")
  }


  func compilePar(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, par: TypePar, inout argIndex: Int) {
    let em = scope.em
    em.str(depth, " \(par.hostName):")
    if argIndex < args.count {
      let arg = args[argIndex]
      if let argLabel = arg.label {
        if let parLabel = par.label {
          if argLabel.name != parLabel.name {
            argLabel.failType("argument label does not match parameter label", notes: (parLabel, "parameter label"))
          }
        } else {
          argLabel.failType("argument label does not match unlabeled parameter", notes: (arg, "unlabeled parameter"))
        }
      }
      let hostName = (arg.label?.name.dashToUnder).or("\"\(argIndex)\"")
      em.str(depth, " \(hostName):")
      arg.compileArg(ctx, scope, depth + 1)
      em.append(",")
      argIndex += 1
    } else { // TODO: support default arguments.
      failType("missing argument for parameter")
    }
    em.append(",")
  }
}

