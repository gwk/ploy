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
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    var retType = expType
    em.str(depth, isTail ? "{{v:" : "{")
    if expType === typeAny {
      var pars = [TypeValPar]()
      for (i, arg) in args.enumerate() {
        let hostName = (arg.label?.name.dashToUnder).or("\"\(i)\"")
        em.str(depth, " \(hostName):")
        let typeVal = arg.compileArg(em, depth + 1, scope, typeAny)
        em.append(",")
        pars.append(TypeValPar(index: i, label: arg.label, typeVal: typeVal, form: nil))
      }
      retType = TypeValCmpd(pars: pars)
    } else if let expCmpd = expType as? TypeValCmpd {
      var argIndex = 0
      for par in expCmpd.pars {
        self.compilePar(em, depth, scope, par: par, argIndex: &argIndex)
      }
      if argIndex != expCmpd.pars.count {
        failType("expected \(expCmpd.pars.count) arguments; received \(argIndex)")
      }
    } else {
      self.failType("expected type: \(expType); received compound value.")
    }
    em.append(isTail ? "}}" : "}")
    return retType
  }
  
  func compilePar(em: Emit, _ depth: Int, _ scope: Scope, par: TypeValPar, inout argIndex: Int) {
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
      arg.compileArg(em, depth + 1, scope, par.typeVal)
      argIndex++
    } else if let dflt = par.form?.dflt {
      dflt.compileExpr(em, depth + 1, scope, par.typeVal, isTail: false)
    } else {
      failType("missing argument for parameter", notes: (par.form, "parameter here"))
    }
    em.append(",")
  }
}

