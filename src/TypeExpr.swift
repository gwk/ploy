// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum TypeExpr: SubForm {

  case cmpdType(CmpdType)
  case path(Path)
  case reify(Reify)
  case sig(Sig)
  case sym(Sym)

  init(form: Form, subj: String, exp: String) {
    if let form = form as? CmpdType   { self = .cmpdType(form) }
    else if let form = form as? Path  { self = .path(form) }
    else if let form = form as? Reify { self = .reify(form) }
    else if let form = form as? Sig   { self = .sig(form) }
    else if let form = form as? Sym   { self = .sym(form) }
    else {
      form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
    }
  }

  init(form: Form, subj: String) {
    self.init(form: form, subj: subj, exp: "type expression")
  }

  var form: Form {
    switch self {
    case cmpdType(let cmpdType): return cmpdType 
    case path(let path): return path
    case reify(let reify): return reify
    case sig(let sig): return sig
    case sym(let sym): return sym
    }
  }


 func typeForTypeExpr(_ scope: Scope, _ subj: String) -> Type {
   switch self {

     case cmpdType(let cmpdType): 
       return Type.Cmpd(cmpdType.pars.map { $0.typeParForPar(scope, subj) })

    case path(let path):
      return path.syms.last!.typeForTypeRecord(scope.record(path: path), subj)

    case reify:
      fatalError()

    case sig(let sig):
      return Type.Sig(par: sig.send.typeForTypeExpr(scope, "signature send"),
        ret: sig.ret.typeForTypeExpr(scope, "signature return"))

    case sym(let sym):
      return sym.typeForTypeRecord(scope.record(sym: sym), subj)
    }
  }
}
