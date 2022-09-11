use std::{cell::RefCell, f64::consts::TAU, rc::Rc};

use cgmath::{InnerSpace, Quaternion, Rad, Rotation3, Vector3};
use geometric_algebra::{
    pga3::{Dir, Translator},
    Powf,
};
use winit::event::{ElementState, KeyboardInput, MouseScrollDelta, VirtualKeyCode, WindowEvent};

use crate::{
    camera,
    entity::{self},
    mesh,
    numeric::quat_to_rotor,
    renderer, rigid, shapes, solver, spatial,
};

pub struct World {
    pub camera: camera::Camera,
    grid: entity::Entity,
    axes: entity::Entity,
    cube: entity::Entity,
    rigid: RefCell<rigid::Rigid>,
}

impl World {
    pub fn new(renderer: &renderer::Renderer) -> World {
        let _library = mesh::debug::Library::new(renderer);

        let grid = entity::Entity::new()
            .meshes(vec![Rc::new(mesh::Mesh::new_grid(renderer, 2, 10))])
            .spatial(
                spatial::Spatial::identity()
                    .scale(20.0)
                    .translator(Translator::new(-1.0, -1.0, 0.0).powf(10.0)),
            );

        let axes = entity::Entity::new()
            .meshes(vec![Rc::new(mesh::Mesh::new_axes(renderer))])
            .spatial(spatial::Spatial::translation(0.0, 0.0, 0.1));

        let mut cube_shape = shapes::Shape::cube();
        for p in cube_shape.points.iter_mut() {
            *p = (p.dir() - Dir::new(0.5, 0.5, 0.5)).point()
        }

        let cube = entity::Entity::new().meshes(vec![Rc::new(
            mesh::Mesh::from_shape(renderer, cube_shape, None)
                .fill(mesh::Fill::Solid)
                .lit(true),
        )]);

        let mut rigid = rigid::Rigid::new(1.0);
        rigid.external_force.z = -3.0;
        // rigid.velocity.z = -0.2;
        // rigid.frame.position.z = 2.0;
        // rigid.frame.quaternion =
        //     Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        rigid.frame.quaternion = Quaternion::from_angle_z(Rad(1.0));
        rigid.frame.position.z = 1.0;
        rigid.internal_torque.x = 1.5;
        rigid.past_frame = rigid.frame;

        World {
            camera: camera::Camera::initial(),
            axes,
            grid,
            cube,
            rigid: RefCell::new(rigid),
        }
    }

    pub fn input(&mut self, event: &WindowEvent) -> bool {
        match event {
            WindowEvent::MouseWheel {
                delta: MouseScrollDelta::PixelDelta(delta),
                ..
            } => {
                self.camera.orbit += 0.003 * delta.x;
                self.camera.tilt += 0.003 * delta.y;
            }

            WindowEvent::TouchpadMagnify { delta, .. } => {
                self.camera.distance *= 1.0 - delta;
            }

            WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state: ElementState::Pressed,
                        virtual_keycode: Some(VirtualKeyCode::Back),
                        ..
                    },
                ..
            } => {
                // Move camera back to initial position while minimizing the path of travel
                let initial = camera::Camera::initial();
                let mut delta_orbit = initial.orbit - self.camera.orbit;
                delta_orbit %= TAU;
                if delta_orbit > TAU / 2.0 {
                    delta_orbit -= TAU;
                } else if delta_orbit < -TAU / 2.0 {
                    delta_orbit += TAU;
                }
                self.camera = camera::Camera {
                    orbit: self.camera.orbit + delta_orbit,
                    ..initial
                };
            }

            _ => return false,
        }
        self.camera.clamp_tilt();
        true
    }

    pub fn integrate(&mut self, _t: f64, dt: f64) {
        solver::integrate(&self.rigid, dt as f32, 25);

        let rigid = self.rigid.borrow();

        self.cube.spatial.translator = Translator::new(
            rigid.frame.position.x,
            rigid.frame.position.y,
            rigid.frame.position.z,
        );

        self.cube.spatial.rotor = quat_to_rotor(rigid.frame.quaternion);
    }

    pub fn entity(&self) -> entity::Entity {
        let mut root = entity::Entity::new();
        root.sub_entities.push(self.grid.clone());
        root.sub_entities.push(self.axes.clone());
        root.sub_entities.push(self.cube.clone());
        root
    }
}
