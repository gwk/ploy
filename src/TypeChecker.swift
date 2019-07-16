// Copyright © 2019 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeChecker {

  enum Comparison {
    case exact
    case subtype
    case free
    // Incompatibilities/errors.
    case unionSrcMemberNotInDst
    case srcNotInUnionDst
    case structToNullDst
    case structSrcMissingLabFields
    case structSrcMissingPosFields
    case structMismatchedLabels
    case structSrcExtraneousPosField
    case structSrcExtraneousLabField
    case structSrcTagNotInDstVariants
    case structMissingVariantMember
    case uncomparable // Generic error.

    var is_compatible: Bool {
      switch self {
        case .exact, .subtype, .free: return true
        default: return false
      }
    }

    mutating func combine(_ right: Comparison) {
      assert(self.is_compatible) // Incompatibilities be handled before computation of `right`.
      if !right.is_compatible { self = right }
      else if self == .free || right == .free { self = .free }
      else if self == .subtype || right == .subtype { self = .subtype }
      else if self == .exact && right == .exact { self = .exact }
      else { fatalError("impossible combination.") }
    }
  }

  enum incompatibilityIndex {
    case unionSrcMember(Int)
    case dom
    case ret
    case posField(Int, Int) // Src, dst indexes.
    case labField(Int, Int) // Src, dst indexes.
    case variant(Int, Int) // Src, dst indexes.
  }

  var assignments:[Int:Type] = [:]
  var freeNevers = Set<Int>() // Never types are a special case, omitted from unification.
  var incompatibilityPath:[incompatibilityIndex] = [] // In reverse (unwinding) order.

  var desc: String {
    return """
    assignments: \(assignments)
    freeNevers: \(freeNevers)
    """
  }


  mutating func unify(freeIndex: Int, type: Type) {
    assignments.insertNew(freeIndex, value: type)
  }


  mutating func compare(src: Type, dst: Type) -> Comparison {

    if src == dst { return .exact }

    switch (src.kind, dst.kind) {

    case (.free, .free):
      return .free

    case (.free(let freeIndex), _):
      // If dst is Never then it is ok to unify; the caller expects to never return.
      unify(freeIndex: freeIndex, type: dst)
      return .exact

    //case (.poly, .sig): // select a single morph.
    //  return try resolvePolyToSig(rel, src: src, dst: dst)

    case (_, .free(let ie)):
      if src == typeNever {
        // If actual is Never, then do not unify; other code paths may return, and we want that type to bind to the free dst.
        // However this might be the only branch, so we need to remember the Never and fall back to it if dst remains free.
        freeNevers.insert(ie)
      } else {
        unify(freeIndex: ie, type: src)
      }
      return .exact

    case (.union(let srcMembers), .union(let dstMembers)):
      for (i, srcMember) in srcMembers.enumerated() {
        if !dstMembers.contains(srcMember) {
          incompatibilityPath.append(.unionSrcMember(i))
          return .unionSrcMemberNotInDst
        }
      }
      return .subtype

    case (_, .union(let members)):
      if !members.contains(src) {
        return .srcNotInUnionDst
      }
      return .subtype

    case (.sig(let srcDR), .sig(let dstDR)):
      return compareSigToSig(src: srcDR, dst: dstDR)

    case (.struct_(let srcFV), .struct_(let dstFV)):
      if dst == typeNull { return .structToNullDst } // Explictly disallow subtyping of Null/Unit type.
      return compareStructToStruct(src: srcFV, dst: dstFV)

    case (.struct_(_, _, let srcVariants), .variantMember(let dstVariant)):
      return compareStructToVariantMember(srcVariants: srcVariants, dstVariant: dstVariant)

    case (_, .prim) where dst == typeAny:
      return .subtype

    default: return .uncomparable
    }
  }


  mutating func compareSigToSig(src: (dom: Type, ret: Type), dst: (dom: Type, ret: Type)) -> Comparison {
    var comparison = compare(src: dst.dom, dst: src.dom) // Domain is contravariant; note reversal.
    if !comparison.is_compatible {
      incompatibilityPath.append(.dom)
      return comparison
    }
    comparison.combine(compare(src: src.ret, dst: dst.ret)) // Return is covariant.
    if !comparison.is_compatible {
      incompatibilityPath.append(.ret)
    }
    return comparison
  }


  mutating func compareStructToStruct(
   src: (posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant]),
   dst: (posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant])) -> Comparison {

    let spc = src.posFields.count
    let dpc = dst.posFields.count
    let slc = src.labFields.count
    let sfc = spc + slc
    let dfc = dpc + dst.labFields.count
    var si = 0

    var comparison:Comparison = .exact

    // Positional fields.
    for (di, dstType) in dst.posFields.enumerated() {
      if si == spc {
        incompatibilityPath.append(.posField(si, di))
        return .structSrcMissingPosFields
      }
      let srcType = src.posFields[si]
      comparison.combine(compare(src: srcType, dst: dstType))
      if !comparison.is_compatible {
        incompatibilityPath.append(.posField(si, di))
        return comparison
      }
      si += 1
    }

    // Labeled Fields.
    for (di, dstField) in dst.labFields.enumerated() {
      let srcType: Type
      if si == sfc {
        incompatibilityPath.append(.posField(si, di))
        return .structSrcMissingLabFields
      } else if si >= spc { // Src labeled field; check that labels match.
        let srcField = src.labFields[si-spc]
        if srcField.label != dstField.label {
          incompatibilityPath.append(.posField(si, di))
          return .structMismatchedLabels
        }
        srcType = srcField.type
      } else { // Src positional field for dst labeled field.
        srcType = src.posFields[si]
      }
      comparison.combine(compare(src: srcType, dst: dstField.type))
      if !comparison.is_compatible {
        incompatibilityPath.append(.labField(si, di))
        return comparison
      }
      si += 1
    }
    if si < spc { // Src struct has extraneous positional field.
      incompatibilityPath.append(.labField(si, dpc))
      return .structSrcExtraneousPosField
    }
    if si < sfc { // Src struct has extraneous labeled field.
      incompatibilityPath.append(.labField(si, dfc))
      return .structSrcExtraneousLabField
    }

    // Variants.
    let dstVariants:[String:(Int, TypeVariant)] = Dictionary(uniqueKeysWithValues: dst.variants.enumerated().map {
      ($0.1.label, $0) })

    for (svi, srcVariant) in src.variants.enumerated() {
      let label = srcVariant.label
      guard let (dvi, dstVariant) = dstVariants[label] else { // Src tag not found in dst set.
        incompatibilityPath.append(.variant(svi, -1))
        return .structSrcTagNotInDstVariants
      }
      comparison.combine(compare(src: srcVariant.type, dst: dstVariant.type))
      if !comparison.is_compatible {
          incompatibilityPath.append(.variant(svi, dvi))
         return comparison
      }
    }
    return comparison
  }


  mutating func compareStructToVariantMember(srcVariants: [TypeVariant], dstVariant: TypeVariant) -> Comparison {
    for srcVariant in srcVariants {
      if srcVariant.label == dstVariant.label {
        return compare(src: srcVariant.type, dst: dstVariant.type)
      }
    }
    return .structMissingVariantMember
  }
}
