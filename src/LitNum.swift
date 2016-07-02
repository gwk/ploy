// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class LitNum: _Form { // numeric literal: `0`.
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
}

