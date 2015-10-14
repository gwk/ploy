// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Scope: CustomStringConvertible {
  let pathNames: [String]
  let hostPrefix: String
  let parent: Scope?
  
  var bindings: [String: ScopeRecord] = [:]
  
  init(pathNames: [String], parent: Scope?) {
    self.pathNames = pathNames
    self.hostPrefix = pathNames.isEmpty ? "" : (pathNames.joinWithSeparator("__") + "__")
    self.parent = parent
  }

  var description: String {
    return "\(self.dynamicType):\(pathNames.joinWithSeparator("/"))"
  }

  func getRecord(sym: Sym) -> ScopeRecord? { fatalError() }

  var name: String { return pathNames.joinWithSeparator("/") }
  
  var globalSpace: Space {
    var scope = self
    while let p = scope.parent {
      scope = p
    }
    return scope as! Space
  }

  func addRecord(sym: Sym, kind: ScopeRecord.Kind) -> ScopeRecord {
    if let existing = bindings[sym.name] {
      if case .Fwd = existing.kind {
        assert(existing.sym!.name == sym.name)
        bindings.removeValueForKey(sym.name)
      } else {
        sym.failRedef(existing.sym)
      }
    }
    let r = ScopeRecord(sym: sym, hostName: hostPrefix + sym.hostName, kind: kind)
    bindings[sym.name] = r
    return r
  }
  
  func addValRecord(key: String, type: Type) {
    assert(!bindings.contains(key))
    bindings[key] = ScopeRecord(sym: nil, hostName: key, kind: .Val(type))
  }
  
  func record(sym: Sym) -> ScopeRecord {
    if let r = getRecord(sym) {
      return r
    }
    if let parent = parent {
      return parent.record(sym)
    }
    sym.failUndef()
  }
  
  func record(path: Path) -> ScopeRecord {
    var space: Space = globalSpace
    for (i, sym) in path.syms.enumerate() {
      guard let r = space.getRecord(sym) else {
        sym.failUndef()
      }
      if i == path.syms.lastIndex! {
        return r
      }
      if case .Space(let s) = r.kind {
        space = s
      } else {
        sym.failType("expected a space; found a \(r.kind.kindDesc)")
      }
    }
    fatalError()
  }
}

