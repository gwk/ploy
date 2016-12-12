// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class LitNum: Form { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    self.val = val
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \(val)\n")
  }

  // MARK: LitNum.

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type { // TODO: move to Prop type refinement.
    switch accesseeType.kind {
    case .cmpd(let fields):
      if let field = fields.optEl(val) {
        return field.type
      } else {
        failType("numeric accessor is out of range for type: \(accesseeType)")
      }
    default:
      failType("numeric literal cannot access into value of type: \(accesseeType)")
    }
  }
}

