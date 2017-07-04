// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Syn: CustomStringConvertible {

  let src: Src
  let pos: Pos
  let visEnd: Pos // position past the last visible character.
  let end: Pos // position past the last member character, including whitespace.

  var hasEndSpace: Bool { return visEnd.idx < end.idx }
  var hasEndLine: Bool { return src.text[visEnd.idx..<end.idx].contains(ucb("\n")) }
  var visRange: Range<Int> { return pos.idx..<visEnd.idx }
  var range: Range<Int> { return pos.idx..<end.idx }

  init(src: Src, pos: Pos, visEnd: Pos, end: Pos) {
    self.src = src
    self.pos = pos
    self.visEnd = visEnd
    self.end = end
  }

  convenience init(pos: Pos, bodySyn: Syn) {
    self.init(src: bodySyn.src, pos: pos, visEnd: bodySyn.visEnd, end: bodySyn.end)
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
      endStr = "--\(visEnd.line + 1):\(visEnd.col)"
    }
    return "\(src.path.withoutPathDir.withoutPathExt):\(pos.line + 1):\(pos.col + 1)\(endStr)"
  }
}
