use cgmath::vec3;

use crate::{debug, geometry, rigid, solver};

#[derive(Debug, Clone, Copy)]
pub struct World {
    pub a: rigid::Rigid,
    pub b: rigid::Rigid,
}

impl World {
    pub fn new(p1: &geometry::Polytope, p2: &geometry::Polytope) -> World {
        let mut a = rigid::Rigid::new(p1.rigid_metrics(1.0));
        let mut b = rigid::Rigid::new(p2.rigid_metrics(1.0));

        a.external_force.z = -5.0;
        a.velocity.z = -0.2;
        a.angular_velocity.x = 1.0;
        a.angular_velocity.y = 0.5;
        a.position = vec3(0.5, 0.5, 0.5);
        a.position.z += 2.0;

        b.external_force.z = -5.0;
        b.velocity.z = -0.2;
        b.angular_velocity.x = 1.0;
        b.angular_velocity.y = 0.5;
        // b.position = vec3(0.5, 0.5, 0.5);
        b.position.z += 2.0;
        b.position.x += 2.0;

        World { a, b }
    }

    pub fn integrate(
        &mut self,
        dt: f64,
        p1: &geometry::Polytope,
        p2: &geometry::Polytope,
        debug: &mut debug::DebugLines,
    ) {
        solver::step(&mut self.a, p1, dt, 25);

        debug.point(self.a.position, [0.0, 0.0, 1.0]);
        debug.point(self.a.position + self.a.center_of_mass, [1.0, 1.0, 0.0]);

        solver::step(&mut self.b, p2, dt, 25);

        debug.point(self.b.position, [0.0, 0.0, 1.0]);
        debug.point(self.b.position + self.b.center_of_mass, [1.0, 1.0, 0.0]);
    }
}
