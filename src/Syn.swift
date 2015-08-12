// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


class Syn: CustomStringConvertible {
  
  let src: Src
  let pos: Pos
  let visEnd: Pos // position past the last visible character.
  let end: Pos // position past the last member character, including whitespace.
  
  var hasSpace: Bool { return visEnd.idx < end.idx }
  var visRange: Range<String.CharacterView.Index> { return Range(start: pos.idx, end: visEnd.idx) }
  var range: Range<String.CharacterView.Index> { return Range(start: pos.idx, end: end.idx) }
  
  var visString: String { return String(src.text[visRange]) }
  var string: String { return String(src.text[range]) }
  
  init(src: Src, pos: Pos, visEnd: Pos, end: Pos) {
    self.src = src
    self.pos = pos
    self.visEnd = visEnd
    self.end = end
  }
  
  convenience init(_ l: Syn, _ r: Syn) {
    self.init(src: l.src, pos: l.pos, visEnd: r.visEnd, end: r.end)
  }
  
  var description: String {
    var endStr = ""
    if pos.line == visEnd.line {
      if pos.col < visEnd.col - 1 {
        endStr = "-\(visEnd.col)"
      }
    } else {
      endStr = "-\(visEnd.line + 1):\(visEnd.col)"
    }
    return "\(pos.line + 1):\(pos.col + 1)\(endStr)"
  }
  
  @noreturn func fail(prefix: String, _ msg: String) { src.fail(pos, visEnd, prefix, msg) }
  
  @noreturn func syntaxFail(msg: String) { fail("syntax error", msg) }
  
}
