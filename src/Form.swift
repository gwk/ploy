// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


protocol Form : Streamable {
  var syn: Syn { get }
  var syntaxName: String { get }
  func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int)
}

protocol Expr: Form {}

protocol TypeExpr: Form {} // TODO: eventually TypeExpr will conform to Expr.

protocol Stmt: Form {}

protocol Def: Form {}


class _Form : Streamable {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }
  
  var syntaxName: String { return String(self.dynamicType) }
  
  func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write("\n")
  }
  
  func writeTo<Target : OutputStreamType>(inout target: Target) {
    writeTo(&target, 0)
  }

  func emit(em: Emit, _ depth: Int) { fatalError() }
}


func castForm<T>(form: Form, _ subj: String, _ exp: String) -> T {
  // TODO: should be able to parameterize as <T: Form> but 2.0b7 does not like it.
  if let form = form as? T {
    return form
  } else {
    form.syn.syntaxFail("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
  
}

