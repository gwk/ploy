// © 2016 George King. Permission to use this file is granted in license.txt.


struct Constraint {
  let actExpr: Expr
  let expForm: Form?
  let actType: Type
  let actChain: Chain<String>
  let expType: Type
  let expChain: Chain<String>
  let desc: String

  var actDesc: String { return actChain.map({"\($0) -> "}).join() }
  var expDesc: String { return expChain.map({"\($0) -> "}).join() }
}


