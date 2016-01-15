// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: _Form, Accessor, Expr { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    assert(val >= 0)
    self.val = val
    super.init(syn)
  }
  
  //var description: String { return String(val) }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(String(val))
    target.write("\n")
  }

  var hostAccessor: String {
    return "[\"\(val)\"]"
  }

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type {
    switch accesseeType.kind {
    case .Cmpd(let pars, _, _):
      if let par = pars.get(val) {
        return par.type
      } else {
        failType("numeric accessor is out of range for type: \(accesseeType)")
      }
    default:
      failType("numeric literal cannot access into value of type: \(accesseeType)")
    }
  }

  func compileAccess(em: Emitter, _ depth: Int, accesseeType: Type) {
    em.str(depth, hostAccessor)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    fatalError()
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    fatalError()
  }
  
  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) -> Type {
    let em = scope.em
    // TODO: typecheck.
    em.str(depth, isTail ? "{v:\(val.dec)}" : val.dec)
    return typeInt
  }
}

