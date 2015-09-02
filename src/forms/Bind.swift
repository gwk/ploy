// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Stmt, Def { // value binding: `name=expr`.
  let sym: Sym
  let val: Expr
  
  init(_ syn: Syn, sym: Sym, val: Expr) {
    self.sym = sym
    self.val = val
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Bind(Syn(l.syn, r.syn),
      sym: castForm(l, "binding", ""),
      val: castForm(r, "binding", ""))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    val.writeTo(&target, depth + 1)
  }
  
  func compileStmt(em: Emit, _ depth: Int, _ scope: Scope) {
    em.str(depth, "let \(scope.hostPrefix)\(sym.hostName) =")
    let typeVal = val.compileExpr(em, depth + 1, scope, typeAny)
    scope.addRec(sym, isFwd: false, kind: .Val(typeVal))
  }
  
  func compileDef(em: Emit, _ scope: Scope) {
    let fullName = "\(scope.name)/\(sym.name)"
    let hostName = "\(scope.hostPrefix)\(sym.hostName)"
    // TODO: decide if lazy def is necessary.
    em.str(0, "var \(hostName)__acc = function() {")
    em.str(0, " \(hostName)__acc = function() {")
    em.str(0, "  throw \"error: lazy value '\(fullName)' recursively referenced during initialization.\" };")
    em.str(0, " let val =")
    let typeVal = val.compileExpr(em, 1, scope, typeAny) // TODO: new scope?
    em.append(";")
    em.str(0, " \(hostName)__acc = function() { return val };")
    em.str(0, " return val; }")
    scope.addRec(sym, isFwd: false, kind: .Lazy(typeVal))
  }
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    if let ann = val as? Ann {
      return .Lazy(ann.type.typeVal(scope, "type annnotation"))
    } else {
      val.failSyntax("definition requires explicit type annotation")
    }
  }
}

