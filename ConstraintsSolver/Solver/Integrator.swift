//
//  Integrator.swift
//  ConstraintsSolver
//
//  Created by Jim on 11.04.21.
//

import Foundation

class Solver {
    let subStepCount: Int
    
    init(subStepCount: Int) {
        self.subStepCount = subStepCount
    }
    
    func integrate(_ rigids: [Rigid], by dt: Double) {
        let subdt = dt / Double(subStepCount)
        let compliance = 1e-6 / subdt.sq
        
        for _ in 0 ..< subStepCount {
            for i in rigids.indices {
                let rigid = rigids[i]
                rigid.integrateAttitude(by: subdt)
                
                var constraints: [Constraint] = []
                for j in i + 1 ..< rigids.count {
                    let other = rigids[j]
                    constraints += generateConstraints(for: rigid, and: other)
                }
                
                for constraint in constraints {
                    let difference = constraint.measure - constraint.targetMeasure
                    let lagrangeFactor = difference / (constraint.inverseResistance + compliance)
                    constraint.act(factor: lagrangeFactor)
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
            case let .box(box):
                return box.intersect(attachedTo: rigid, with: box, attachedTo: other)
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
