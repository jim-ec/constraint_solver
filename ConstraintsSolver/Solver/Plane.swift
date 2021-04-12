//
//  Plane.swift
//  ConstraintsSolver
//
//  Created by Jim on 11.04.21.
//

import Foundation

struct Plane {
    let normal: Point
    let offset: Double
    
    var support: Point {
        offset * normal
    }
    
    init(direction: Point, offset: Double) {
        normal = direction.normalize
        self.offset = offset
    }
    
    init(_ triangle: (Point, Point, Point)) {
        normal = triangle.0.to(triangle.1).cross(triangle.0.to(triangle.2)).normalize
        let support = triangle.0.project(onto: normal)
        if support.dot(normal) > 0 {
            offset = support.length
        }
        else {
            offset = -support.length
        }
    }
}
