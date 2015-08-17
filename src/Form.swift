// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


protocol Form : Streamable {
  var syn: Syn { get }
  var syntaxName: String { get }
  func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int)
  func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal
  @noreturn func fail(prefix: String, _ msg: String, _ notes: (Form, String)?...)
  @noreturn func failSyntax(msg: String)
}

protocol Expr: Form {}

protocol TypeExpr: Form { // TODO: eventually TypeExpr will conform to Expr.
  func typeVal(scope: Scope, _ subj: String) -> TypeVal
}

protocol Stmt: Form {}

protocol Def: Form {}


class _Form : Streamable {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }
  
  var syntaxName: String { return String(self.dynamicType) }
  
  @noreturn func fail(prefix: String, _ msg: String, _ notes: (Form, String)?...) {
    syn.src.errPos(syn.pos, end: syn.end, prefix: prefix, msg: msg)
    for n in notes {
      if let (form, msg) = n {
        form.syn.src.errPos(form.syn.pos, end: form.syn.end, prefix: "note", msg: msg)
      }
    }
    Process.exit(1)
  }

  @noreturn func failSyntax(msg: String) { fail("syntax error", msg) }
  
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

  func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal { fatalError() }
}


/// castForm uses return type polymorphism to implicitly choose the protocol to cast to.
func castForm<T>(form: Form, _ subj: String, _ exp: String) -> T {
  // TODO: should be able to parameterize as <T: Form> but 2.0b7 does not like that.
  if let form = form as? T {
    return form
  } else {
    form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
  
}

