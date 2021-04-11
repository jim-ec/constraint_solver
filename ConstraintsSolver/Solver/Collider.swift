class Collider {
    let points: [Point]
    var rigidBody: RigidBody
    
    init(rigidBody: RigidBody) {
        self.rigidBody = rigidBody
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
    
    var vertices: [(Point, Point)] {
        points.map { p in (p, rigidBody.space.act(p)) }
    }
    
    func intersectWithGround() -> [PositionalConstraint] {
        vertices
            .filter { _, position in position.z < 0 }
            .map { local, position in
                let targetPosition = position.planeProjection(normal: .ez)
                
                let deltaPosition = rigidBody.delta(local)
                let deltaTangentialPosition = deltaPosition - deltaPosition.project(onto: position.to(targetPosition))
                
                return PositionalConstraint(
                    body: rigidBody,
                    positions: (position, targetPosition - deltaTangentialPosition),
                    distance: 0,
                    compliance: 0.0000001
                )
            }
    }
}
