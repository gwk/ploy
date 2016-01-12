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

  func compileExprBodyWithNaturalType(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope) -> Type {
    let em = scope.em
    var pars = [TypePar]()
    for (i, arg) in args.enumerate() {
      let hostName = (arg.label?.name.dashToUnder).or("\"\(i)\"")
      em.str(depth, " \(hostName):")
      let type = arg.compileArg(ctx, depth + 1, scope, typeEvery)
      em.append(",")
      pars.append(TypePar(index: i, label: arg.label, type: type, form: nil))
    }
    return Type.Cmpd(pars)
  }

  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    let em = scope.em
    var actType = expType
    em.str(depth, isTail ? "{{v:" : "{")
    switch expType.kind {
    case .All(let members, _, _):
      if members.count == 0 { // anything.
        assert(expType === typeEvery)
        actType = compileExprBodyWithNaturalType(ctx, depth, scope)
      } else {
        self.failType("expected type: \(expType); received compound value.")
      }
    case .Cmpd(let pars, _, _):
      var argIndex = 0
      for par in pars {
        self.compilePar(ctx, depth, scope, par: par, argIndex: &argIndex)
      }
      if argIndex != pars.count {
        failType("expected \(pars.count) arguments; received \(argIndex)")
      }
    case .Free: // TODO: do not ignore free variable index; need to do real type inference.
      actType = compileExprBodyWithNaturalType(ctx, depth, scope)
    default:
      self.failType("expected type: \(expType); received compound value.")
    }
    em.append(isTail ? "}}" : "}")
    return actType
  }
  
  func compilePar(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, par: TypePar, inout argIndex: Int) {
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
          argLabel.failType("argument label does not match unlabeled parameter", notes: (par.form, "unlabeled parameter"))
        }
      }
      arg.compileArg(ctx, depth + 1, scope, par.type)
      argIndex++
    } else if let dflt = par.form?.dflt {
      dflt.compileExpr(ctx, depth + 1, scope, par.type, isTail: false)
    } else {
      failType("missing argument for parameter", notes: (par.form, "parameter here"))
    }
    em.append(",")
  }
}

