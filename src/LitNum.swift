// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitNum: Form { // numeric literal: `0`.
  let val: Int

  init(_ syn: Syn, val: Int) {
    self.val = val
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, suffix: ": \(val)\n")
  }

  var cloned: LitNum {
    return LitNum(syn, val: val)
  }
}

