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

use crate::{camera, debug, geometry, mesh, renderer, world};

pub const CAMERA_RESPONSIVNESS: f32 = 0.5;
pub const FRAME_TIME: f64 = 1.0 / 60.0;
pub const DEFAULT_COLOR: [f32; 3] = [0.4; 3];

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
    let p1 = geometry::Polytope::new_tetrahedron();
    let p2 = geometry::Polytope::new_icosahedron();
    let m1 = mesh::Mesh::from_polytope(&renderer, &p1);
    let m2 = mesh::Mesh::from_polytope(&renderer, &p2);

    let mut camera = camera::Camera::initial();
    let mut camera_target = camera;

    let mut dragging = false;
    let mut paused = false;
    let mut manual_forward_step = false;
    let mut time_speed_up = false;

    let mut states = vec![(world::World::new(&p1, &p2), debug::DebugLines::default())];
    let mut current_state: usize = 0;

    event_loop.run(move |event, _, control_flow| {
        let time_speed = || if time_speed_up { 5 } else { 1 };

        match event {
            Event::NewEvents(winit::event::StartCause::Init) => {
                window.set_visible(true);
            }

            Event::DeviceEvent { event, .. } => match event {
                DeviceEvent::MouseMotion { delta } => {
                    if dragging {
                        camera_target.orbit += 0.01 * delta.0 as f32;
                        camera_target.tilt += 0.01 * delta.1 as f32;
                        camera_target.clamp_tilt();
                    }
                }
                DeviceEvent::MouseWheel { delta } => {
                    let sensitivity = match delta {
                        MouseScrollDelta::PixelDelta(delta) => 0.001 * delta.y as f32,
                        MouseScrollDelta::LineDelta(_, y) => 0.05 * y as f32,
                    };
                    camera_target.distance =
                        (camera_target.distance * (1.0 - sensitivity)).clamp(2.0, 100.0);
                }
                _ => {}
            },

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
                            virtual_keycode: Some(VirtualKeyCode::Up),
                            ..
                        },
                    ..
                } if paused => {
                    manual_forward_step = true;
                }

                WindowEvent::KeyboardInput {
                    input:
                        KeyboardInput {
                            state: ElementState::Pressed,
                            virtual_keycode: Some(VirtualKeyCode::Down),
                            ..
                        },
                    ..
                } if paused => {
                    current_state = current_state.saturating_sub(time_speed());
                }

                WindowEvent::ModifiersChanged(state) => {
                    time_speed_up = state.shift();
                }

                WindowEvent::Resized(size)
                | WindowEvent::ScaleFactorChanged {
                    new_inner_size: &mut size,
                    ..
                } => {
                    renderer.resize(size);
                    window.request_redraw();
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

                WindowEvent::MouseInput { state, button, .. } => match (button, state) {
                    (MouseButton::Left, ElementState::Pressed) => dragging = true,
                    (MouseButton::Left, ElementState::Released) => dragging = false,
                    _ => {}
                },

                _ => {}
            },

            Event::RedrawRequested(..) => {
                last_render_time = Instant::now();

                if !paused || manual_forward_step {
                    for _ in 0..time_speed() {
                        if current_state + 1 >= states.len() {
                            let mut world = states[current_state].0;
                            let mut debug_lines = debug::DebugLines::default();
                            world.integrate(FRAME_TIME, &p1, &p2, &mut debug_lines);
                            states.push((world, debug_lines));
                        }
                        current_state += 1;
                    }
                    manual_forward_step = false;
                }

                camera.orbit = camera.orbit.lerp(camera_target.orbit, CAMERA_RESPONSIVNESS);
                camera.tilt = camera.tilt.lerp(camera_target.tilt, CAMERA_RESPONSIVNESS);
                camera.distance = camera
                    .distance
                    .lerp(camera_target.distance, CAMERA_RESPONSIVNESS);

                let (world, debug_lines) = &states[current_state];

                let geometry = [
                    (&m1, world.a.frame(), world.a.color.unwrap_or(DEFAULT_COLOR)),
                    (&m2, world.b.frame(), world.b.color.unwrap_or(DEFAULT_COLOR)),
                ];

                match renderer.render(&camera, &geometry, debug_lines) {
                    Ok(_) => {}
                    Err(wgpu::SurfaceError::Lost) => renderer.resize(renderer.size),
                    Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                    Err(wgpu::SurfaceError::Timeout) | Err(wgpu::SurfaceError::Outdated) => (),
                }
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
        }
    });
}
