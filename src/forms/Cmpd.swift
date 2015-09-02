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
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    if let expCmpd = expType as? TypeValCmpd {
      em.str(depth, "{")
      var argIndex = 0
      for par in expCmpd.pars {
        self.compilePar(em, depth + 1, scope, par: par, argIndex: &argIndex)
      }
      em.append("}")
      if argIndex != expCmpd.pars.count {
        failType("expected \(expCmpd.pars.count) arguments; received \(argIndex)")
      }
      return expType
    }
    // TODO: assemble actual type from arguments.
    //var actPars: [TypeValPar] = []
    self.failType("expected type: \(expType); received compound value.")
  }
  
  func compilePar(em: Emit, _ depth: Int, _ scope: Scope, par: TypeValPar, inout argIndex: Int) {
    em.str(depth, " \(par.par.hostName):")
    if argIndex < args.count {
      let arg = args[argIndex]
      if let argLabel = arg.label {
        if let parLabel = par.par.label {
          if argLabel.name != parLabel.name {
            argLabel.failType("argument label does not match parameter label", notes: (parLabel, "parameter label here"))
          }
        } else {
          argLabel.failType("argument label does not match unlabeled parameter", notes: (par.par, "parameter here"))
        }
      }
      arg.compileArg(em, depth, scope, par.typeVal)
      argIndex++
    } else if let dflt = par.par.dflt {
      dflt.compileExpr(em, depth, scope, par.typeVal)
    } else {
      failType("missing argument for parameter", notes: (par.par, "parameter here"))
    }
    em.append(",")
  }
}

