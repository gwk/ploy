// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum TypeExpr: SubForm {

  case cmpdType(CmpdType)
  case path(Path)
  case reify(Reify)
  case sig(Sig)
  case sym(Sym)

  init(form: Form, subj: String) {
    if let form = form as? CmpdType   { self = .cmpdType(form) }
    else if let form = form as? Path  { self = .path(form) }
    else if let form = form as? Reify { self = .reify(form) }
    else if let form = form as? Sig   { self = .sig(form) }
    else if let form = form as? Sym   { self = .sym(form) }
    else {
      form.failSyntax("\(subj) expects type expression but received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
    case .cmpdType(let cmpdType): return cmpdType
    case .path(let path): return path
    case .reify(let reify): return reify
    case .sig(let sig): return sig
    case .sym(let sym): return sym
    }
  }


  func type(_ scope: Scope, _ subj: String) -> Type {
    switch self {

    case .cmpdType(let cmpdType):
      return Type.Cmpd(cmpdType.pars.enumerated().map {
        (index, par) in
        return par.typeParForPar(scope, index: index)
      })

    case .path(let path):
      return scope.typeBinding(path: path, subj: subj)

    case .reify:
      fatalError()

    case .sig(let sig):
      return Type.Sig(par: sig.send.type(scope, "signature send"), ret: sig.ret.type(scope, "signature return"))

    case .sym(let sym):
      return scope.typeBinding(sym: sym, subj: subj)
    }
  }
}
