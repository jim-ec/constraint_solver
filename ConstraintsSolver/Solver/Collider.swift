class Collider {
    let vertices: [double3]
    var rigidBody: RigidBody
    
    init(rigidBody: RigidBody) {
        self.rigidBody = rigidBody
        vertices = [
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
    
    var globalVertices: [double3] {
        vertices.map(rigidBody.toGlobal)
    }
    
    func intersectWithGround() -> [PositionalConstraint] {
        let penetratingVertices = globalVertices.filter { vertex in vertex.z < 0 }
        return penetratingVertices.map { position in
            let targetPosition = double3(position.x, position.y, 0)
            let difference = targetPosition - position
            
            let deltaPosition = position - rigidBody.fromGlobalToPreviousGlobal(position)
            let deltaTangentialPosition = deltaPosition - project(deltaPosition, difference)
            
            return PositionalConstraint(
                body: rigidBody,
                positions: (position, targetPosition - deltaTangentialPosition),
                distance: 0,
                compliance: 0.0000001
            )
        }
    }
}
