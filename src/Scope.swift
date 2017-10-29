// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Scope: CustomStringConvertible {
  let pathNames: [String]
  let hostPrefix: String
  let parent: Scope?

  var bindings: [String: ScopeRecord] = [:]

  init(pathNames: [String], parent: Scope?) {
    self.pathNames = pathNames
    self.hostPrefix = pathNames.isEmpty ? "" : (pathNames.joined(separator: "__") + "__")
    self.parent = parent
  }

  var description: String {
    return "\(type(of: self)):\(pathNames.joined(separator: "/"))"
  }

  func getRecordInFrame(sym: Sym) -> ScopeRecord? { fatalError() }

  var name: String { return pathNames.joined(separator: "/") }

  var globalSpace: Space {
    var scope = self
    while let p = scope.parent {
      scope = p
    }
    return scope as! Space
  }

  func addRecord(sym: Sym, kind: ScopeRecord.Kind) -> ScopeRecord {
    if let existing = bindings[sym.name] {
      switch existing.kind {
      case .fwd: assert(existing.sym?.name == sym.name)
      default: sym.failRedef(original: existing.sym)
      }
    }
    let r = ScopeRecord(name: sym.name, hostName: hostPrefix + sym.hostName, sym: sym, kind: kind)
    bindings[sym.name] = r
    return r
  }

  func addValRecord(name: String, type: Type) {
    assert(!bindings.contains(key: name))
    bindings[name] = ScopeRecord(name: name, sym: nil, kind: .val(type))
  }

  func getRecord(sym: Sym) -> ScopeRecord {
    if let r = getRecordInFrame(sym: sym) {
      return r
    }
    if let parent = parent {
      return parent.getRecord(sym: sym)
    }
    sym.failUndef()
  }

  func getRecord(path: SymPath) -> ScopeRecord {
    var space: Space = globalSpace
    for (i, sym) in path.syms.enumerated() {
      guard let rec = space.getRecordInFrame(sym: sym) else {
        sym.failUndef()
      }
      if i == path.syms.lastIndex! {
        return rec
      }
      if case .space(let s) = rec.kind {
        space = s
      } else {
        sym.failScope("expected a space; found a \(rec.kindDesc).")
      }
    }
    fatalError()
  }

  func getRecord(identifier: Identifier) -> ScopeRecord {
    switch identifier {
    case .sym(let sym): return getRecord(sym: sym)
    case .path(let path): return getRecord(path: path)
    }
  }

  func typeBinding(sym: Sym, subj: String) -> Type {
    let rec = getRecord(sym: sym)
    switch rec.kind {
    case .type(let type): return type
    default: sym.failScope("\(subj) expected a type; `\(rec.name)` refers to a \(rec.kindDesc).")
    }
  }

  func typeBinding(path: SymPath, subj: String) -> Type {
    let rec = getRecord(path: path)
    switch rec.kind {
    case .type(let type): return type
    default: path.failScope("\(subj) expected a type; `\(rec.name)` refers to a \(rec.kindDesc).")
    }
  }
}
