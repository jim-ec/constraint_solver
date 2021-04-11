//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 28.10.20.
//

import Foundation

//struct MinkowskiDifference {
//    let convexVolumes: (ConvexVolume, ConvexVolume)
//
//    init(_ a: ConvexVolume, _ b: ConvexVolume) {
//        convexVolumes = (a, b)
//    }
//
//    /// Returns the point within the Minkowski difference which is furthest away from the origin in the given direction.
//    subscript (in direction: simd_double3) -> simd_double3 {
//        convexVolumes.0.furthestPoint(in: direction) - convexVolumes.1.furthestPoint(in: -direction)
//    }
//}
//
//protocol ConvexVolume {
//    func furthestPoint(in direction: simd_double3) -> simd_double3
//}
//
///// 0-, 1-, or 2-simplices which arise during the iterations of the GJK algorithm.
//fileprivate enum IntermediateSimplex {
//    case point(simd_double3)
//    case line(simd_double3, simd_double3)
//    case triangle(simd_double3, simd_double3, simd_double3)
//}
//
//typealias Tetrahedron = (simd_double3, simd_double3, simd_double3, simd_double3)
//
///// The simplex after an iteration is either still an intermediate one, or the final tetrahedron which contains the origin.
//fileprivate enum NextSimplex {
//    case intermediate(IntermediateSimplex)
//    case containingTetrahedron(Tetrahedron)
//}
//
//func gjk(a: ConvexVolume, b: ConvexVolume) -> Bool {
//    let support = MinkowskiDifference(a, b)
//
//    let initialPoint = support[in: simd_double3.random(in: 0...1)]
//    var simplex = IntermediateSimplex.point(initialPoint)
//    var searchDirection = -initialPoint
//
//    while true {
//        let nextPoint = support[in: searchDirection]
//
//        if dot(nextPoint, searchDirection) <= 0 {
//            // No collision possible anymore.
//            return false
//        }
//
//        switch nextSimplex(simplex: simplex, point: nextPoint, direction: &searchDirection) {
//        case let .intermediate(nextSimplex):
//            simplex = nextSimplex
//        case .containingTetrahedron:
//            return true
//        }
//    }
//}
//
//fileprivate func nextSimplex(simplex: IntermediateSimplex, point a: simd_double3, direction: inout simd_double3) -> NextSimplex {
//    switch simplex {
//    case let .point(b):
//        return .intermediate(processLine(a, b, direction: &direction))
//    case let .line(b, c):
//        return .intermediate(processTriangle(a, b, c, direction: &direction))
//    case let .triangle(b, c, d):
//        if let simplex = processTetrahedron(a, b, c, d, direction: &direction) {
//            return .intermediate(simplex)
//        }
//        else {
//            return .containingTetrahedron(Tetrahedron(a, b, c, d))
//        }
//    }
//}
//
//extension simd_double3 {
//    func cross(_ x: simd_double3) -> simd_double3 {
//        simd.cross(self, x)
//    }
//
//    func dot(_ x: simd_double3) -> Double {
//        simd.dot(self, x)
//    }
//}
//
//fileprivate func sameDirection(_ a: simd_double3, _ b: simd_double3) -> Bool {
//    dot(a, b) > 0
//}
//
//fileprivate func processLine(_ a: simd_double3, _ b: simd_double3, direction: inout simd_double3) -> IntermediateSimplex {
//    let ao = -a
//    let ab = b - a
//    if sameDirection(cross(a, b), ao) {
//        direction = ab.cross(ao).cross(ab)
//        return .line(a, b)
//    }
//    else {
//        direction = ao
//        return .point(a)
//    }
//}
//
//fileprivate func processTriangle(_ a: simd_double3, _ b: simd_double3, _ c: simd_double3, direction: inout simd_double3) -> IntermediateSimplex {
//    let ao = -a
//    let ab = b - a
//    let ac = c - a
//    let abc = ab.cross(ac)
//
//    if sameDirection(abc.cross(ac), ao) {
//        if sameDirection(ac, ao) {
//            direction = ac.cross(ao).cross(ac)
//            return .line(a, c)
//        }
//        else {
//            return processLine(a, b, direction: &direction)
//        }
//    }
//    else {
//        if sameDirection(ab.cross(abc), ao) {
//            return processLine(a, b, direction: &direction)
//        }
//        else if sameDirection(abc, ao) {
//            direction = abc
//            return .triangle(a, b, c)
//        }
//        else {
//            direction = -abc
//            return .triangle(a, c, b)
//        }
//    }
//}
//
//fileprivate func processTetrahedron(_ a: simd_double3, _ b: simd_double3, _ c: simd_double3, _ d: simd_double3, direction: inout simd_double3) -> IntermediateSimplex? {
//    let ab = b - a
//    let ac = c - a
//    let ad = d - a
//    let ao = -a
//
//    let abc = ab.cross(ac)
//    let acd = ac.cross(ad)
//    let adb = ad.cross(ab)
//
//    if sameDirection(abc, ao) {
//        return processTriangle(a, b, c, direction: &direction)
//    }
//    else if sameDirection(acd, ao) {
//        return processTriangle(a, c, d, direction: &direction)
//    }
//    else if sameDirection(adb, ao) {
//        return processTriangle(a, d, b, direction: &direction)
//    }
//    else {
//        return .none
//    }
//}
