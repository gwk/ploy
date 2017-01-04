// © 2016 George King. Permission to use this file is granted in license.txt.


struct Constraint {
  let actExpr: Expr
  let expExpr: Expr?
  let actType: Type
  let actChain: Chain<String>
  let expType: Type
  let expChain: Chain<String>
  let desc: String
}


