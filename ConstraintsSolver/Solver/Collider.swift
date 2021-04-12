
enum Collider {
    case plane(Plane)
    case box(BoxCollider)
}

struct BoxCollider {
    let points: [Point]
    
    init() {
        points = [
            .init(-1, -1, -1),
            .init(1, -1, -1),
            .init(-1, 1, -1),
            .init(1, 1, -1),
            .init(-1, -1, 1),
            .init(1, -1, 1),
            .init(-1, 1, 1),
            .init(1, 1, 1)
        ].map { 0.5 * $0 }
    }
    
    func apply(frame: Frame) -> [Point] {
        points.map { frame.act($0) }
    }
    
    func intersect(attachedTo rigid: Rigid, with p: Plane, attachedTo other: Rigid) -> [Constraint] {
        var constraints: [Constraint] = []
        let plane = other.frame.act(p)
        
        for position in points.map(rigid.frame.act) {
            if position.reject(from: plane).dot(plane.normal) >= 0 {
                continue
            }
            
            let targetPosition = position.project(onto: plane)
            let correction = position.to(targetPosition)
            
            let deltaPosition = rigid.delta(global: position)
            let deltaTangentialPosition = deltaPosition - deltaPosition.project(onto: correction)
            
            constraints.append(PositionalConstraint(
                rigids: (rigid, other),
                positions: (position, targetPosition - 1 * deltaTangentialPosition),
                distance: 0,
                compliance: 0.0000001
            ))
        }
        
        return constraints
    }
    
//    func intersect(attachedTo rigid: Rigid, with b: BoxCollider, attachedTo otherRigid: Rigid) -> [Constraint] {
//        var constraints: [Constraint] = []
//
//        if let m = MinkowskiDifference(a: apply(frame: rigid.frame), b: b.apply(frame: otherRigid.frame)) {
//            // Collision detected
//            let correction = m.minimum
//
//            // TODO: Generate constraint
//        }
//
//        return constraints
//    }
}
