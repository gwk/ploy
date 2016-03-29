// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


protocol Form : Streamable, CustomStringConvertible {
  var syn: Syn { get }
  var syntaxName: String { get }
  var description: String { get }

  @noreturn func failForm(prefix: String, msg: String, notes: (Form?, String)...)
  @noreturn func failSyntax(msg: String, notes: (Form?, String)...)
  @noreturn func failType(msg: String, notes: (Form?, String)...)

  func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int)
}

protocol Accessor: Form {
  var hostAccessor: String { get }
  var propAccessor: Type.PropAccessor { get }
  func compileAccess(em: Emitter, _ depth: Int, accesseeType: Type)
}


protocol Def: Form {
  var sym: Sym { get }
  @warn_unused_result
  func compileDef(space: Space) -> ScopeRecord.Kind
}


protocol Expr: Form {
  @warn_unused_result
  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type
  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool)
}


protocol Identifier: Form {
  var name: String { get }
  var syms: [Sym] { get }
  @warn_unused_result
  func record(scope: Scope, _ sym: Sym) -> ScopeRecord
}


protocol TypeExpr: Form { // TODO: eventually TypeExpr will conform to Expr.
  @warn_unused_result
  func typeForTypeExpr(scope: Scope, _ subj: String) -> Type
}


class _Form : Form, Hashable {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var syntaxName: String { return String(self.dynamicType) }

  var description: String {
    var s = ""
    writeTo(&s, 0)
    return s
  }

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

func ==(l: _Form, r: _Form) -> Bool { return l === r }


/// castForm uses return type polymorphism to implicitly choose the protocol to cast to.
@warn_unused_result
func castForm<T>(form: Form, _ subj: String, _ exp: String) -> T {
  // TODO: should be able to parameterize as <T: Form> but 2.0b6 does not like that.
  if let form = form as? T {
    return form
  } else {
    form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
  
}

