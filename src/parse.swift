// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


func parseFileAtPath(path: String) -> Syn {
  let src = Src(path: path)
  let pos = Pos(idx: 0, line: 0, col: 0)
  let end = Pos(idx: src.text.count, line: 0, col: 0)
  return Syn(kind: .File, src: src, pos: pos, visEnd: end, end: end, subs: [])
}
