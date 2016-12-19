// © 2016 George King. Permission to use this file is granted in license.txt.

import Quilt


struct Constraint {
  let form: Form
  let expForm: Form?
  let actType: Type
  let actChain: Chain<String>
  let expType: Type
  let expChain: Chain<String>
  let desc: String

  var actDesc: String { return actChain.map({"\($0) "}).join() }
  var expDesc: String { return expChain.map({"\($0) "}).join() }

  func subConstraint(actType: Type, actDesc: String?, expType: Type, expDesc: String?) -> Constraint {
    return Constraint(form: form, expForm: expForm,
      actType: actType, actChain: (actDesc == nil) ? actChain : .link(actDesc!, actChain),
      expType: expType, expChain: (expDesc == nil) ? expChain : .link(expDesc!, expChain),
      desc: desc)
  }

  func fail(act: Type, exp: Type, msg: String) -> Never {
    if let expForm = expForm {
      form.failType("\(desc) \(msg). \(actDesc)actual type: \(act)",
        notes: (expForm, "\(expDesc)expected type: \(exp)"))
    } else {
      form.failType("\(desc) \(msg). \(actDesc)actual type: \(act); \(expDesc)expected type: \(exp).")
    }
  }
}


