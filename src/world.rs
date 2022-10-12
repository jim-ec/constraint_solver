use cgmath::{vec3, InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{
    debug,
    geometry::{self, Plane, Polytope},
    rigid, solver,
};

#[derive(Debug, Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
}

impl World {
    pub fn new(polytope: &geometry::Polytope) -> World {
        let rigid_metrics = polytope.rigid_metrics(1.0);
        dbg!(rigid_metrics);

        let mut a = rigid::Rigid::new(rigid_metrics);

        // a.external_force.z = -5.0;
        // a.velocity.z = -0.2;
        a.angular_velocity.x = 1.0;
        // a.angular_velocity.y = 0.5;
        a.frame.position.z = 2.0;
        a.center_of_mass.y = 0.5;

        World { a }
    }

    pub fn integrate(
        &mut self,
        dt: f64,
        polytope: &geometry::Polytope,
        debug: &mut debug::DebugLines,
    ) {
        solver::step(&mut self.a, polytope, dt, 25);

        debug.point(self.a.frame.position, [0.0, 0.0, 1.0]);
        debug.point(self.a.frame.act(self.a.center_of_mass), [1.0, 1.0, 0.0]);
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.a]
    }
}
