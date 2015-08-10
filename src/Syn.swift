// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


enum SynKind {
  case Acc      // accessor: `field@val.`
  case Alias    // type alias: `TypeName := TypeExpr`.
  case Ann      // annotation: `val:Type`.
  case Bind     // value binding: `name=expr`.
  case Call     // function call: `f.a`.
  case CallAdj  // function call implied by adjacency to aggregate: `f(a b)`.
  case Case     // conditional case: `condition ? consequence`.
  case Do       // do block: `{…}`.
  case Enum     // enum declaration: `enum E variants…;`.
  //case Flt
  case File     // top-level container.
  case Fn       // function declaration: `fn type body…;`
  case HostDecl // host declaration: `PLOY-HOST name Type;`.
  case If       // if statement: `if cases… default;`
  case LitNum   // numeric literal: `0`.
  case LitStr   // string literal: `'hi', "hi"`.
  case Pub      // public modifier: `pub stmt;`
  case Reify    // type reification:  `T^A`.
  case ReifyAdj // type reification implied by adjacency to tuple: `T<A B>`.
  case Scoped   // local scope: `scoped body…;`
  case Struct   // struct declaration: `struct S fields…;`.
  case Sig      // function signature: `Par%Ret`.
  case Sym      // symbol: `name`.
  case Tup      // tuple type: `<A B>`.
}


class Syn {
  
  let kind: SynKind
  let src: Src
  let pos: Pos
  let visEnd: Pos // position past the last visible character.
  let end: Pos // position past the last member character, including whitespace.
  let subs: [Syn]
  
  var visRange: Range<String.CharacterView.Index> { return Range(start: pos.idx, end: visEnd.idx) }
  var range: Range<String.CharacterView.Index> { return Range(start: pos.idx, end: end.idx) }
  
  var visString: String { return String(src.text[visRange]) }
  var string: String { return String(src.text[range]) }
  
  
  init(kind: SynKind, src: Src, pos: Pos, visEnd: Pos, end: Pos, subs: [Syn]) {
    self.kind = kind
    self.src = src
    self.pos = pos
    self.visEnd = visEnd
    self.end = end
    self.subs = subs
  }
  

}
