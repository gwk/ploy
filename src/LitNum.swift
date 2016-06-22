// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: _Form, Accessor, Expr { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    assert(val >= 0)
    self.val = val
    super.init(syn)
  }
  
  //var description: String { return String(val) }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \(val)\n")
  }

  var hostAccessor: String {
    return "._\(val)"
  }

  var propAccessor: Type.PropAccessor {
    return .index(val)
  }

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type { // TODO: move to Prop type refinement.
    switch accesseeType.kind {
    case .cmpd(let pars, _, _):
      if let par = pars.optEl(val) {
        return par.type
      } else {
        failType("numeric accessor is out of range for type: \(accesseeType)")
      }
    default:
      failType("numeric literal cannot access into value of type: \(accesseeType)")
    }
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = typeInt
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, isTail ? "{v:\(val.dec)}" : val.dec)
  }
}

