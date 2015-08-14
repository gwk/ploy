// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRec {
  enum Kind {
    case Type
    case Val
    case Lazy
  }
  
  let kind: Kind
  let typeVal: TypeVal
}


class Scope {
  let parent: Scope?
  let isModule: Bool
  var bindings: [String: ScopeRec] = [:]

  init(parent: Scope?, isModule: Bool) {
    self.parent = parent
    self.isModule = isModule
  }
}