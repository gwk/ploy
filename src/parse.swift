// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


func parseFileAtPath(path: String) -> Syn {
  let src = Src(path: path)
  let pos = src.startPos
  return Syn(kind: .File, src: src, pos: pos, visEnd: pos, end: pos, subs: [])
}
