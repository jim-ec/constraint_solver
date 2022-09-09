use std::{f64::consts::TAU, rc::Rc};

use geometric_algebra::{pga3::Translator, Powf};
use winit::event::{ElementState, KeyboardInput, MouseScrollDelta, VirtualKeyCode, WindowEvent};

use crate::{
    camera,
    entity::{self},
    mesh, renderer, spatial,
};

pub struct Game {
    pub camera: camera::Camera,
    grid: entity::Entity,
    entities: Vec<entity::Entity>,
}

impl Game {
    pub fn new(renderer: &renderer::Renderer) -> Game {
        let axes = entity::Entity::new()
            .meshes(vec![Rc::new(mesh::Mesh::new_axes(renderer))])
            .spatial(spatial::Spatial::translation(0.0, 0.0, 0.1));

        let _library = mesh::debug::Library::new(renderer);

        Game {
            entities: vec![axes],
            camera: camera::Camera::initial(),
            grid: entity::Entity::new()
                .meshes(vec![Rc::new(mesh::Mesh::new_grid(renderer, 2, 10))])
                .spatial(
                    spatial::Spatial::identity()
                        .scale(20.0)
                        .translator(Translator::new(-1.0, -1.0, 0.0).powf(10.0)),
                ),
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

    pub fn integrate(&mut self, _t: f64, _dt: f64) {}

    pub fn entity(&self) -> entity::Entity {
        let mut root = entity::Entity::new();
        root.sub_entities.push(self.grid.clone());
        root.sub_entities.extend(self.entities.iter().cloned());
        root
    }
}
