// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


struct Constraint {
  let actForm: Form
  let actType: Type
  let actChain: Chain<String>
  let expForm: Form
  let expType: Type
  let expChain: Chain<String>
  let desc: String

  var actDesc: String { return actChain.map({"\($0) of\n"}).join() }
  var expDesc: String { return expChain.map({"\($0) of\n"}).join() }

  func subConstraint(actType: Type, actDesc: String?, expType: Type, expDesc: String?) -> Constraint {
    return Constraint(
      actForm: actForm, actType: actType, actChain: (actDesc == nil) ? actChain : .link(actDesc!, actChain),
      expForm: expForm, expType: expType, expChain: (expDesc == nil) ? expChain : .link(expDesc!, expChain), desc: desc)
  }

  func fail(act: Type, exp: Type, msg: String) -> Never {
    actForm.failType(
      "\(msg);\n\(actDesc)\(desc);\nactual type: \(act)",
      notes: (expForm, "\n\(expDesc)\(desc);\nexpected type: \(exp)"))
  }
}


