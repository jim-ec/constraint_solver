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
}