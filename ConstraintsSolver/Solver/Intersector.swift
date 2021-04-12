//
//  Intersector.swift
//  ConstraintsSolver
//
//  Created by Jim on 11.04.21.
//

import Foundation


struct MinkowskiDifference {
    var points: [Point]
    var center: Point
    
    init?(a: [Point], b: [Point]) {
        center = .null
        points = []
        for va in a {
            for vb in b {
                let difference = va - vb
                points.append(difference)
                center = center + difference
            }
        }
        center = (1 / Double(points.count)) * center
        
        if points.count > 4 {
            return nil
        }
        
        let posX = points.contains { $0.x > 0 }
        let negX = points.contains { $0.x < 0 }
        let posY = points.contains { $0.y > 0 }
        let negY = points.contains { $0.y < 0 }
        let posZ = points.contains { $0.z > 0 }
        let negZ = points.contains { $0.z < 0 }
        let includesOrigin = posX && negX && posY && negY && posZ && negZ
        
        if !includesOrigin {
            return nil
        }
    }
    
    var minimum: Point {
        points.min { (a, b) -> Bool in
            a.length < b.length
        }!
    }
    
    func planeInDirection(of direction: Point) -> Plane {
        var sorted = points
        sorted.sort { (a, b) -> Bool in
            a.dot(direction) < b.dot(direction)
        }
        let plane = Plane((sorted[0], sorted[1], sorted[2]))
        
        // Ensure that plane normal points in the same direction as the given one.
        if plane.normal.dot(direction) > 0 {
            return plane
        }
        else {
            return plane.flip
        }
    }
}


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
