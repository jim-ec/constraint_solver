use cgmath::{Deg, Euler, Quaternion, Rotation3};

use crate::{collision, debug, geometry, rigid};

#[derive(Debug, Clone, Copy)]
pub struct World {
    pub a: rigid::Rigid,
    pub b: rigid::Rigid,
}

impl World {
    pub fn new(p1: &geometry::Polytope, p2: &geometry::Polytope) -> World {
        let a = rigid::Rigid::new(p1.rigid_metrics(0.1));
        let mut b = rigid::Rigid::new(p2.rigid_metrics(0.1));

        b.position.x = 0.8;
        b.position.y = 0.2;
        b.position.z = 0.95;
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
        if collision::sat((self.a.frame(), self.b.frame()), (p1, p2), debug) {
            self.a.color = None;
            self.b.color = None;
        } else {
            // self.a.color = Some([1.0, 0.0, 0.0]);
            // self.b.color = Some([1.0, 0.0, 0.0]);
        }

        // solver::step(&mut self.a, p1, dt, 25);

        // debug.point(self.a.position, [0.0, 0.0, 1.0]);
        // debug.point(self.a.position + self.a.center_of_mass, [1.0, 1.0, 0.0]);

        // solver::step(&mut self.b, p2, dt, 25);

        // debug.point(self.b.position, [0.0, 0.0, 1.0]);
        // debug.point(self.b.position + self.b.center_of_mass, [1.0, 1.0, 0.0]);
    }
}
