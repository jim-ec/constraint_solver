//
//  EPA.swift
//  ConstraintsSolver
//
//  Created by Jim Eckerlein on 14.11.20.
//

import Foundation

fileprivate struct ExpandingPolytope {
    var points: [simd_double3] = []
    var triangles: [(Int, Int, Int)]
    
    init(from tetrahedron: Tetrahedron) {
        points = [tetrahedron.0, tetrahedron.1, tetrahedron.2, tetrahedron.3]
        triangles = [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)]
    }
    
    func nearestOrthogonalProjection() -> simd_double3 {
        var minimalSquaredDistance = Double.infinity
        var nearestOrthogonalProjection = simd_double3.zero
        
        for triangle in triangles {
            let points = (self.points[triangle.0], self.points[triangle.1], self.points[triangle.2])
            let normal = (points.1 - points.0).cross(points.2 - points.0)
            let offset = points.0
            let orthogonalProjection = (normal.dot(-offset)) * normal
            let squaredDistance = length_squared(orthogonalProjection)
            
            if squaredDistance < minimalSquaredDistance {
                minimalSquaredDistance = squaredDistance
                nearestOrthogonalProjection = orthogonalProjection
            }
        }
        
        return nearestOrthogonalProjection
    }
    
    func triangleEdges(of triangle: (Int, Int, Int)) -> [(Int, Int)] {
        return [(triangle.0, triangle.1), (triangle.1, triangle.2), (triangle.2, triangle.0)]
    }
    
    /// Expands the polytope to the given point, while mainting convexity.
    mutating func expand(to x: simd_double3) {
        var seamEdges: [(Int, Int)] = []
        var vanishingEdges: [Bool] = []
        var vanishingTriangles: [Bool] = .init(repeating: false, count: triangles.count)
        
        for (index, triangle) in triangles.enumerated() {
            let points = (self.points[triangle.0], self.points[triangle.1], self.points[triangle.2])
            let normal = (points.1 - points.0).cross(points.2 - points.0)
            
            if normal.dot(x) > 0 {
                vanishingTriangles[index] = true
                
                for edge in triangleEdges(of: triangle) {
                    let reversedEdge = (edge.1, edge.0)
                    var isVanishing = false
                    for (index, seamEdge) in seamEdges.enumerated() {
                        if seamEdge == reversedEdge {
                            vanishingEdges[index] = true
                            isVanishing = true
                            break
                        }
                    }
                    if !isVanishing {
                        seamEdges.append(edge)
                        vanishingEdges.append(false)
                    }
                }
            }
        }
        
        for i in 0..<triangles.count {
            if vanishingTriangles[i] {
                triangles.remove(at: i)
            }
        }
        
        for (index, seamEdge) in seamEdges.enumerated() {
            if vanishingEdges[index] {
                continue
            }
            
            points.append(x)
            triangles.append((seamEdge.0, seamEdge.1, points.count - 1))
        }
    }
}

func epa(tetrahedron: Tetrahedron, support: MinkowskiDifference) -> simd_double3 {
    var polytope = ExpandingPolytope(from: tetrahedron)
    
    while true {
        let projection = polytope.nearestOrthogonalProjection()
        let actualExtent = support[in: projection]
        
        if length_squared(projection - actualExtent) < 0.01 {
            return projection
        }
        else {
            polytope.expand(to: projection)
        }
    }
}
