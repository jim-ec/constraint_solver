use std::{cell::RefCell, rc::Rc};

use cgmath::{InnerSpace, Quaternion, Rad, Rotation3, Vector3, Zero};

use crate::{
    entity::{self},
    line_debugger, mesh, renderer, rigid, solver,
};

pub struct World {
    cube: entity::Entity,
    rigid: RefCell<rigid::Rigid>,
}

impl World {
    pub fn new(renderer: &renderer::Renderer) -> World {
        let cube = entity::Entity::default().meshes(vec![Rc::new(mesh::Mesh::new_cube(renderer))]);

        let mut rigid = rigid::Rigid::new(1.0);
        rigid.external_force.z = -5.0;
        rigid.velocity.z = -0.2;
        rigid.angular_velocity.z = 1.0;
        rigid.frame.position.z = 5.0;
        rigid.frame.quaternion =
            Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        rigid.past_frame = rigid.frame;

        World {
            cube,
            rigid: RefCell::new(rigid),
        }
    }

    pub fn integrate(&mut self, _t: f32, dt: f32, line_debugger: &mut line_debugger::LineDebugger) {
        solver::integrate(&self.rigid, dt, 25);

        let rigid = self.rigid.borrow();

        self.cube.frame = rigid.frame;

        line_debugger.debug_lines(
            vec![Vector3::zero(), rigid.frame.position],
            Vector3::new(1.0, 1.0, 0.0),
        )
    }

    pub fn entities(&self) -> Vec<entity::Entity> {
        vec![self.cube.clone()]
    }
}
