use cgmath::{InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{frame, line_debugger, mesh, renderer, rigid, solver};

pub struct World {
    cube: mesh::Mesh,
    rigid: rigid::Rigid,

    rigid2: rigid::Rigid,
}

impl World {
    pub fn new(
        renderer: &renderer::Renderer,
        #[allow(unused_variables)] line_debugger: &mut line_debugger::LineDebugger,
    ) -> World {
        let cube = mesh::Mesh::new_cube(renderer);

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

        World {
            cube,
            rigid,
            rigid2,
        }
    }

    pub fn integrate(
        &mut self,
        #[allow(unused_variables)] dt: f64,
        #[allow(unused_variables)] line_debugger: &mut line_debugger::LineDebugger,
    ) {
        solver::step(&mut self.rigid, dt, 25);
    }

    pub fn entities(&mut self) -> Vec<(frame::Frame, &mesh::Mesh)> {
        if self.rigid.gjk(&self.rigid2) {
            self.cube.color = [1.0, 0.0, 0.0];
        } else {
            self.cube.color = mesh::DEFAULT_COLOR;
        }

        vec![
            (self.rigid.frame, &self.cube),
            (self.rigid2.frame, &self.cube),
        ]
    }
}
