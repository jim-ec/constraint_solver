use cgmath::{Deg, Euler, Quaternion, Rotation3};

use crate::{collision, debug, geometry, rigid, solver};

#[derive(Debug, Clone, Copy)]
pub struct World {
    pub a: rigid::Rigid,
    pub b: rigid::Rigid,
}

impl World {
    pub fn new(p1: &geometry::Polytope, p2: &geometry::Polytope) -> World {
        let mut a = rigid::Rigid::new(p1.rigid_metrics(0.1));
        let mut b = rigid::Rigid::new(p2.rigid_metrics(5.0));

        a.position.z = 4.0;
        a.velocity.y = 2.5;
        a.angular_velocity.x = -4.0;
        a.angular_velocity.y = 1.0;
        a.external_force.z = -2.0;

        b.position.x = 4.0;
        b.position.z = 4.0;
        b.velocity.z = 7.0;
        b.angular_velocity.x = -5.0;
        b.angular_velocity.y = 5.0;
        b.external_force.z = -2.0;
        b.rotation = Euler::new(Deg(10.0), Deg(15.0), Deg(5.0)).into();

        World { a, b }
    }

    #[allow(unused)]
    pub fn integrate(
        &mut self,
        dt: f64,
        p1: &geometry::Polytope,
        p2: &geometry::Polytope,
        debug: &mut debug::DebugLines,
    ) {
        solver::step(&mut self.a, p1, dt, 25);
        solver::step(&mut self.b, p1, dt, 25);
    }
}
