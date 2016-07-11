// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: Form { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \(name)\n")
  }

  func typeForAccess(ctx: TypeCtx, accesseeType: Type) -> Type { // TODO: move to Prop type refinement.
    switch accesseeType.kind {
    case .cmpd(let pars, _, _):
      for par in pars {
        if let label = par.label {
          if name == label.name {
            return par.type
          }
        }
      }
      failType("symbol accessor does not match any parameter label of compound type: \(accesseeType)")
    default:
      failType("symbol cannot access into value of type: \(accesseeType)")
    }
  }

  // MARK: Sym
  
  var hostName: String { return name.dashToUnder }
  
  func typeForExprRecord(_ scopeRecord: ScopeRecord) -> Type {
    switch scopeRecord.kind {
    case .lazy(let type): return type
    case .val(let type): return type
    default: failType("expression expects a value; `\(name)` refers to a \(scopeRecord.kindDesc).")
    }
  }
  
  @noreturn func failUndef() {
    failForm(prefix: "scope error", msg: "`\(name)` is not defined in this scope")
  }
  
  @noreturn func failRedef(original: Sym?) {
    failForm(prefix: "scope error", msg: "redefinition of `\(name)`", notes: (original, "original definition here"))
  }
}

