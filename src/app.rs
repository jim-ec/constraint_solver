use itertools::Itertools;
use lerp::Lerp;
use std::{
    f32::consts::TAU,
    time::{Duration, Instant},
};
use winit::{
    event::*,
    event_loop::{ControlFlow, EventLoop},
    window::WindowBuilder,
};

use crate::{camera, debug, mesh, renderer, world};

pub const CAMERA_RESPONSIVNESS: f32 = 0.5;
pub const FRAME_TIME: f64 = 1.0 / 60.0;

pub async fn run() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    let mut last_render_time = Instant::now();
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title("Constraint Solver")
        .with_visible(false)
        .build(&event_loop)
        .unwrap();

    let mut renderer = renderer::Renderer::new(&window).await?;
    let mut debug_lines = debug::DebugLines::default();
    let cube_mesh = mesh::Mesh::new_cube(&renderer);

    let mut world = world::World::new();
    let mut camera = camera::Camera::initial();
    let mut camera_target = camera;

    let mut paused = false;

    event_loop.run(move |event, _, control_flow| match event {
        Event::NewEvents(winit::event::StartCause::Init) => {
            window.set_visible(true);
        }

        Event::WindowEvent { event, .. } => match event {
            WindowEvent::CloseRequested
            | WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state: ElementState::Pressed,
                        virtual_keycode: Some(VirtualKeyCode::Escape),
                        ..
                    },
                ..
            } => *control_flow = ControlFlow::Exit,

            WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state: ElementState::Pressed,
                        virtual_keycode: Some(VirtualKeyCode::Return),
                        ..
                    },
                ..
            } => {
                if window.fullscreen().is_none() {
                    window.set_fullscreen(Some(winit::window::Fullscreen::Borderless(None)))
                } else {
                    window.set_fullscreen(None)
                }
            }

            WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state: ElementState::Pressed,
                        virtual_keycode: Some(VirtualKeyCode::Space),
                        ..
                    },
                ..
            } => {
                paused = !paused;
            }

            WindowEvent::KeyboardInput {
                input:
                    KeyboardInput {
                        state: ElementState::Pressed,
                        virtual_keycode: Some(VirtualKeyCode::Tab),
                        ..
                    },
                ..
            } if paused => {
                world.integrate(FRAME_TIME, &mut debug_lines);
            }

            WindowEvent::Resized(size)
            | WindowEvent::ScaleFactorChanged {
                new_inner_size: &mut size,
                ..
            } => {
                renderer.resize(size);
                window.request_redraw();
            }

            WindowEvent::MouseWheel {
                delta: MouseScrollDelta::PixelDelta(delta),
                ..
            } => {
                camera_target.orbit += 0.003 * delta.x as f32;
                camera_target.tilt += 0.003 * delta.y as f32;
                camera_target.clamp_tilt();
            }

            WindowEvent::TouchpadMagnify { delta, .. } => {
                camera_target.distance *= 1.0 - delta as f32;
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
                let mut delta_orbit = initial.orbit - camera_target.orbit;
                delta_orbit %= TAU;
                if delta_orbit > TAU / 2.0 {
                    delta_orbit -= TAU;
                } else if delta_orbit < -TAU / 2.0 {
                    delta_orbit += TAU;
                }
                camera_target = camera::Camera {
                    orbit: camera_target.orbit + delta_orbit,
                    ..initial
                };
            }

            _ => {}
        },

        Event::RedrawRequested(..) => {
            last_render_time = Instant::now();

            if !paused {
                world.integrate(FRAME_TIME, &mut debug_lines);
            }

            camera.orbit = camera.orbit.lerp(camera_target.orbit, CAMERA_RESPONSIVNESS);
            camera.tilt = camera.tilt.lerp(camera_target.tilt, CAMERA_RESPONSIVNESS);
            camera.distance = camera
                .distance
                .lerp(camera_target.distance, CAMERA_RESPONSIVNESS);

            let geometry = world
                .rigids()
                .into_iter()
                .map(|rigid| (&cube_mesh, rigid.frame, rigid.color))
                .collect_vec();

            match renderer.render(&camera, &geometry, &debug_lines) {
                Ok(_) => {}
                Err(wgpu::SurfaceError::Lost) => renderer.resize(renderer.size),
                Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                Err(wgpu::SurfaceError::Timeout) | Err(wgpu::SurfaceError::Outdated) => (),
            }

            debug_lines.clear();
        }

        Event::MainEventsCleared => {
            let target_frametime = Duration::from_secs_f64(FRAME_TIME);
            let time_since_last_frame = last_render_time.elapsed();
            if time_since_last_frame >= target_frametime {
                window.request_redraw();
            } else {
                *control_flow = ControlFlow::WaitUntil(
                    Instant::now() + target_frametime - time_since_last_frame,
                );
            }
        }

        _ => {}
    });
}
