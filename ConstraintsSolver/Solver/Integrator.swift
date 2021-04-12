//
//  Integrator.swift
//  ConstraintsSolver
//
//  Created by Jim on 11.04.21.
//

import Foundation

class SubStepIntegrator {
    let subStepCount: Int
    
    init(subStepCount: Int) {
        self.subStepCount = subStepCount
    }
    
    func integrate(_ rigids: [Rigid], by dt: Double) {
        let subdt = dt / Double(subStepCount)
        
        for _ in 0 ..< subStepCount {
            for rigid in rigids {
                rigid.integrateAttitude(by: subdt)
                
                var constraints: [Constraint] = []
                for other in rigids {
                    if rigid === other {
                        continue
                    }
                    constraints += generateConstraints(for: rigid, and: other)
                }
                
                for constraint in constraints {
                    constraint.solve(dt: subdt)
                }
                
                rigid.deriveVelocity(for: subdt)
            }
        }
    }
    
    func intersect(for rigid: Rigid, and other: Rigid) -> [Constraint]? {
        switch rigid.collider {
        case let .box(box):
            switch other.collider {
            case let .plane(plane):
                return box.intersect(attachedTo: rigid, with: plane, attachedTo: other)
            case .box(_):
                return nil
            }
        case .plane(_):
            return nil
        }
    }
    
    func generateConstraints(for rigid: Rigid, and other: Rigid) -> [Constraint] {
        if let constraints = intersect(for: rigid, and: other) {
            return constraints
        }
        else if let constraints = intersect(for: other, and: rigid) {
            return constraints
        }
        else {
            return []
        }
    }
}
