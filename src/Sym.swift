// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: Form { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \(name)\n")
  }

  // MARK: Sym

  var hostName: String { return name }

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type { // TODO: move to Prop type refinement.
    switch accesseeType.kind {
    case .cmpd(let fields):
      for field in fields {
        if let label = field.label {
          if name == label {
            return field.type
          }
        }
      }
      failType("symbol accessor does not match any field label of compound type: \(accesseeType)")
    default:
      failType("symbol cannot access into value of type: \(accesseeType)")
    }
  }

  func typeForExprRecord(_ scopeRecord: ScopeRecord) -> Type {
    switch scopeRecord.kind {
    case .lazy(let type): return type
    case .poly(let type, _): return type
    case .val(let type): return type
    default: failType("expected a value; `\(name)` refers to a \(scopeRecord.kindDesc).")
    }
  }

  func failUndef() -> Never {
    failForm(prefix: "scope error", msg: "`\(name)` is not defined in this scope.")
  }

  func failRedef(original: Sym?) -> Never {
    failForm(prefix: "scope error", msg: "redefinition of `\(name)`", notes: (original, "original definition here:"))
  }
}
