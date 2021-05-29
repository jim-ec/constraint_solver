//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim on 11.04.21.
//

import Foundation


extension Array where Element == Point {
    var center: Point {
        return (1 / Double(count)) * dropFirst().reduce(first!) { $0 + $1 }
    }
}


func intersectBoxBox(box: [Point]) -> [(Point, Point)] {
//    if box.center!.length > sqrt(2) {
//        return []
//    }
    
    var constraints: [(Point, Point)] = []

    let distance = box.center.length
    let correction = 2 - distance
    
    if correction < 0 {
        return []
    }
    else {
        let direction = box.center.normalize
        let a = 1 * direction
        let b = box.center - 1 * direction
        return [(b, a)]
    }
    
    // p is inside the box
//    let a = Point(abs(c.x), abs(c.y), abs(c.z))
//    let direction: Point

//    // search for smallest vector correcting the penetrating vertex
//    if a.x > a.y && a.x > a.z {
//        direction = c.x > 0 ? .ex : -.ex
//    }
//    else if a.y > a.x && a.y > a.z {
//        direction = c.y > 0 ? .ey : -.ey
//    }
//    else if a.z > a.y && a.z > a.x {
//        direction = c.z > 0 ? .ez : -.ez
//    }
//    else {
//        direction = .null
//    }
    
    for p in box {
        if abs(p.ex) >= 0.5 || abs(p.ey) >= 0.5 || abs(p.ez) >= 0.5 {
            continue
        }

        // p is inside the box
        let a = Point(abs(p.ex), abs(p.ey), abs(p.ez))
        let correction: Point

        // search for smallest vector correcting the penetrating vertex
        if a.ex > a.ey && a.ex > a.ez {
            correction = Point(p.ex > 0 ? 0.5 : -0.5, p.ey, p.ez)
        }
        else if a.ey > a.ex && a.ey > a.ez {
            correction = Point(p.ex, p.ey > 0 ? 0.5 : -0.5, p.ez)
        }
        else if a.ez > a.ey && a.ez > a.ex {
            correction = Point(p.ex, p.ey, p.ez > 0 ? 0.5 : -0.5)
        }
        else {
            correction = .null
        }
        
        constraints.append((p, correction))

//        let constraint = PositionalConstraint(
//            rigids: rigids,
//            contacts: (p, p + correction),
//            targetDistance: 0,
//            compliance: 0)
//        constraints.append(constraint)
    }
    
    return constraints
}


//struct MinkowskiDifference {
//    var points: [Point]
//    var center: Point
//
//    init?(a: [Point], b: [Point]) {
//        center = .null
//        points = []
//        for va in a {
//            for vb in b {
//                let difference = va - vb
//                points.append(difference)
//                center = center + difference
//            }
//        }
//        center = (1 / Double(points.count)) * center
//
//        if points.count > 4 {
//            return nil
//        }
//
//        let posX = points.contains { $0.x > 0 }
//        let negX = points.contains { $0.x < 0 }
//        let posY = points.contains { $0.y > 0 }
//        let negY = points.contains { $0.y < 0 }
//        let posZ = points.contains { $0.z > 0 }
//        let negZ = points.contains { $0.z < 0 }
//        let includesOrigin = posX && negX && posY && negY && posZ && negZ
//
//        if !includesOrigin {
//            return nil
//        }
//    }
//
//    var minimum: Point {
//        points.min { (a, b) -> Bool in
//            a.length < b.length
//        }!
//    }
//
//    func planeInDirection(of direction: Point) -> Plane {
//        var sorted = points
//        sorted.sort { (a, b) -> Bool in
//            a.dot(direction) < b.dot(direction)
//        }
//        let plane = Plane((sorted[0], sorted[1], sorted[2]))
//
//        // Ensure that plane normal points in the same direction as the given one.
//        if plane.normal.dot(direction) > 0 {
//            return plane
//        }
//        else {
//            return plane.flip
//        }
//    }
//}


//fileprivate typealias Tri = (Point, Point, Point)
//
//
//fileprivate func convexHull(points: [Point]) -> [Tri] {
//    let tris: [Tri] = []
//
//    // Initial step, find extreme points.
//    let initial: Tri = (
//        points.max { a, b in a.x > b.x }!,
//        points.max { a, b in a.y > b.y }!,
//        points.max { a, b in a.z > b.z }!
//    )
//
//    func findMaximalRejection(plane: Plane) -> Point {
//        points.max { a, b in
//            a.reject(from: plane).length > b.reject(from: plane).length
//        }!
//    }
//
//    findMaximalRejection(plane: Plane(initial))
//
//    return tris
//}
