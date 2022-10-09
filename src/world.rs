use cgmath::{Deg, InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{debug, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
    b: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut a = rigid::Rigid::new(1.0);
        a.frame.position.z = 2.0;
        a.frame.position.y = -0.9;
        a.frame.quaternion =
            Quaternion::from_angle_x(Deg(45.0)) * Quaternion::from_angle_y(Deg(45.0));

        let mut b = rigid::Rigid::new(1.0);
        b.frame.position.z = 1.0;

        World { a, b }
    }

    pub fn integrate(&mut self, dt: f64, debug_lines: &mut debug::DebugLines) {
        solver::step(&mut self.a, dt, 25);

        let test = self.a.sat(&self.b, debug_lines);

        if test {
            self.a.color = Some([1.0, 0.0, 0.0]);
            self.b.color = Some([1.0, 0.0, 0.0]);
        } else {
            self.a.color = None;
            self.b.color = None;
        }
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.a, &self.b]
    }
}
