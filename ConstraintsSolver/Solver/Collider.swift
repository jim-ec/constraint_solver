
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
    
    func intersect(attachedTo rigid: Rigid, with plane: Plane, attachedTo otherRigid: Rigid) -> [PositionalConstraint] {
        var constraints: [PositionalConstraint] = []
        
        for position in points.map(rigid.frame.act) {
            if position.reject(from: plane).dot(plane.normal) >= 0 {
                continue
            }
            
            let targetPosition = position.project(onto: plane)
            
            let deltaPosition = rigid.delta(global: position)
            let deltaTangentialPosition = deltaPosition - deltaPosition.project(onto: position.to(targetPosition))
            
            constraints.append(PositionalConstraint(
                rigid: rigid,
                positions: (position, targetPosition - deltaTangentialPosition),
                distance: 0,
                compliance: 0.0000001
            ))
        }
        
        return constraints
    }
}
