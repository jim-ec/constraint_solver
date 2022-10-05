use cgmath::{num_traits::Zero, InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{debug, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    rigid: rigid::Rigid,
    rigid2: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut rigid = rigid::Rigid::new(1.0);
        rigid.external_force.z = -5.0;
        rigid.velocity.z = -0.2;
        rigid.angular_velocity.z = 1.0;
        rigid.frame.position.z = 5.0;
        rigid.frame.quaternion =
            Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        rigid = rigid.forget_past();

        let mut rigid2 = rigid::Rigid::new(1.0);
        rigid2.frame.position.z = 2.1;
        rigid2 = rigid2.forget_past();

        World { rigid, rigid2 }
    }

    pub fn integrate(&mut self, dt: f64, debug_lines: &mut debug::DebugLines) {
        solver::step(&mut self.rigid, dt, 25);

        const DEBUG_GJK: Vector3<f32> = Vector3 {
            x: 1.0,
            y: 0.0,
            z: 1.0,
        };

        if let Some(collision) = self.rigid.epa(&self.rigid2) {
            self.rigid.color = [1.0, 0.0, 0.0];
            self.rigid2.color = [1.0, 0.0, 0.0];
            debug_lines.line(
                vec![Vector3::zero(), collision.depth * collision.normal],
                DEBUG_GJK,
            );
        } else {
            self.rigid.color = rigid::DEFAULT_COLOR;
            self.rigid2.color = rigid::DEFAULT_COLOR;
        }
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.rigid, &self.rigid2]
    }
}
