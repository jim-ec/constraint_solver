
enum Collider {
    case plane(PlaneCollider)
    case box(BoxCollider)
}

struct PlaneCollider {
    let normal: Point
    let offset: Double
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
    
    func intersectWithGround(attachedTo rigid: RigidBody) -> [PositionalConstraint] {
        points.map { p in (p, rigid.frame.act(p)) }
            .filter { _, position in position.z < 0 }
            .map { local, position in
                let targetPosition = position.planeProjection(normal: .ez)
                
                let deltaPosition = rigid.delta(local)
                let deltaTangentialPosition = deltaPosition - deltaPosition.project(onto: position.to(targetPosition))
                
                return PositionalConstraint(
                    body: rigid,
                    positions: (position, targetPosition - deltaTangentialPosition),
                    distance: 0,
                    compliance: 0.0000001
                )
            }
    }
}
