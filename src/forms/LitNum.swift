// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: _Form, Accessor, Expr { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    assert(val >= 0)
    self.val = val
    super.init(syn)
  }
  
  var description: String { return String(val) }
  
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
  
  func compileAccess(em: Emit, _ depth: Int, accesseeType: Type) -> Type {
    em.str(depth, hostAccessor)
    if let accesseeType = accesseeType as? TypeCmpd {
      if let par = accesseeType.pars.get(val) {
        return par.type
      } else {
        failType("numeric accessor is out of range for type: \(accesseeType)")
      }
    } else {
      failType("numeric literal cannot access into value of type: \(accesseeType)")
    }
  }

  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: Type, isTail: Bool) -> Type {
    // TODO: typecheck.
    em.str(depth, isTail ? "{v:\(val.dec)}" : val.dec)
    return typeInt
  }
}

