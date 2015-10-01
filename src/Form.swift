// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


protocol Form : Streamable {
  var syn: Syn { get }
  var syntaxName: String { get }
  func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int)
  @noreturn func failForm(prefix: String, msg: String, notes: (Form?, String)...)
  @noreturn func failSyntax(msg: String, notes: (Form?, String)...)
  @noreturn func failType(msg: String, notes: (Form?, String)...)
}


protocol Accessor: Form, CustomStringConvertible {
  var hostAccessor: String { get }
  func compileAccess(em: Emitter, _ depth: Int, accesseeType: Type) -> Type
}


protocol Def: Form {
  var sym: Sym { get }
  func scopeRecordKind(space: Space) -> ScopeRecord.Kind
  func compileDef(space: Space) -> ScopeRecord.Kind
}


protocol Expr: Form {
  func compileExpr(depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type
}


protocol Identifier: Form {
  func record(scope: Scope, _ sym: Sym) -> ScopeRecord
}


protocol TypeExpr: Form { // TODO: eventually TypeExpr will conform to Expr.
  func typeVal(scope: Scope, _ subj: String) -> Type
}


protocol Stmt: Form {
  func compileStmt(depth: Int, _ scope: LocalScope)
}


class _Form : Form {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var syntaxName: String { return String(self.dynamicType) }

  @noreturn func failForm(prefix: String, msg: String, notes: [(Form?, String)]) {
    syn.src.errPos(syn.pos, end: syn.visEnd, prefix: prefix, msg: msg)
    for (form, msg) in notes {
      if let form = form {
        form.syn.src.errPos(form.syn.pos, end: form.syn.visEnd, prefix: "note", msg: msg)
      }
    }
    Process.exit(1)
  }
  
  @noreturn func failForm(prefix: String, msg: String, notes: (Form?, String)...) {
    failForm(prefix, msg: msg, notes: notes)
  }

  @noreturn func failSyntax(msg: String, notes: (Form?, String)...) {
    failForm("syntax error", msg: msg, notes: notes)
  }
  
  @noreturn func failType(msg: String, notes: (Form?, String)...) {
    failForm("type error", msg: msg, notes: notes)
  }
  
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
}


/// castForm uses return type polymorphism to implicitly choose the protocol to cast to.
func castForm<T>(form: Form, _ subj: String, _ exp: String) -> T {
  // TODO: should be able to parameterize as <T: Form> but 2.0b6 does not like that.
  if let form = form as? T {
    return form
  } else {
    form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
  
}

