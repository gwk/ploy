// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


struct Src: CustomStringConvertible {
  let path: String
  let text: String
  
  var description: String { return "Src(\(path))" }
  
  init(path: String) {
    self.path = path
    self.text = InFile(path: path).read()
  }
  
  func adv(pos: Pos, dist: Int = 1) -> Pos? {
    var idx = pos.idx
    var d = dist
    while d > 0 {
      idx = idx.successor()
      if idx == text.characters.endIndex { return nil }
      d--
    }
    return Pos(idx: idx, line: pos.line, col: pos.col + dist)
  }
  
  func advLine(pos: Pos) -> Pos? {
    let idx = pos.idx.successor()
    if idx == text.characters.endIndex { return nil }
    return Pos(idx: idx, line: pos.line + 1, col: 0)
  }
  
  var startPos: Pos { return Pos(idx: text.characters.startIndex, line: 0, col: 0) }
  
  //func dist(end: Pos) -> Int { return end.idx - idx }

  //func hasSome(pos: Pos, ahead: Int = 0) -> Bool { return pos.idx + ahead < text.count }
  
  //func hasNext(pos: Pos) -> Bool { return hasSome(pos, ahead: 1) }
  
  //func hasStr(pos: Pos, str: String) {}
}
