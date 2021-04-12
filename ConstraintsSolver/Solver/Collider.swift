
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
    
    func intersect(attachedTo rigid: Rigid, with b: BoxCollider, attachedTo other: Rigid) -> [Constraint] {
        var constraints: [Constraint] = []
        
        let d = intersectBoxBox(box: b.apply(frame: other.frame).map { rigid.frame.inverse.act($0) })
            .map { a, b in (rigid.frame.act(a), rigid.frame.act(b)) }
        
        let g = intersectBoxBox(box: apply(frame: rigid.frame).map { other.frame.inverse.act($0) })
            .map { a, b in (other.frame.act(a), other.frame.act(b)) }
        
        if !d.isEmpty {
            other.frame.position = other.frame.position + (d[0].0.to(d[0].1))
            return []
        }
        
        for (a, b) in d + g {
            constraints.append(PositionalConstraint(
                                rigids: (rigid, other),
                                positions: (a, b),
                                distance: 0,
                                compliance: 0))
        }
        
        return constraints
    }
}
