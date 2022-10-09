use cgmath::{InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{debug, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
    b: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut a = rigid::Rigid::new(1.0);
        a.external_force.z = -5.0;
        a.velocity.z = -0.2;
        a.angular_velocity.z = 1.0;
        a.frame.position.z = 5.0;
        a.frame.quaternion =
            Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        a = a.forget_past();

        let mut b = rigid::Rigid::new(1.0);
        b.frame.position.z = 2.1;
        b = b.forget_past();

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
