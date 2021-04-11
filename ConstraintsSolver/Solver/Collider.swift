
enum Collider {
    case plane(PlaneCollider)
    case box(BoxCollider)
}

struct PlaneCollider {
    let plane: Plane
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
        ].map { v in 0.5 * v }
    }
    
    func intersectWithGround(attachedTo rigid: Rigid) -> [PositionalConstraint] {
        let plane = Plane(normal: .ez, offset: 0)
        
        return points.map { p in rigid.frame.act(p) }
            .filter { position in position.reject(from: plane).dot(plane.normal) < 0 }
            .map { position in
                let targetPosition = position.project(onto: plane)
                
                let deltaPosition = rigid.delta(global: position)
                let deltaTangentialPosition = deltaPosition - deltaPosition.project(onto: position.to(targetPosition))
                
                return PositionalConstraint(
                    rigid: rigid,
                    positions: (position, targetPosition - deltaTangentialPosition),
                    distance: 0,
                    compliance: 0.0000001
                )
            }
    }
}
