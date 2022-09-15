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

use crate::{camera, line_debugger, renderer, world};

pub const CAMERA_RESPONSIVNESS: f32 = 0.5;

pub async fn run() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    let time_start = Instant::now();
    let mut last_render_time = Instant::now();
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title("Constraint Solver")
        .with_visible(false)
        .build(&event_loop)
        .unwrap();

    let mut renderer = renderer::Renderer::new(&window).await?;
    let mut line_debugger = line_debugger::LineDebugger::new(&renderer);

    let mut world = world::World::new(&renderer);
    let mut camera = camera::Camera::initial();
    let mut camera_target = camera;

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
            let time = Instant::now();
            let delta_time = time.duration_since(last_render_time);
            last_render_time = time;

            world.integrate(
                time.duration_since(time_start).as_secs_f32(),
                delta_time.as_secs_f32(),
                &mut line_debugger,
            );

            camera.orbit = camera.orbit.lerp(camera_target.orbit, CAMERA_RESPONSIVNESS);
            camera.tilt = camera.tilt.lerp(camera_target.tilt, CAMERA_RESPONSIVNESS);
            camera.distance = camera_target
                .distance
                .lerp(camera_target.distance, CAMERA_RESPONSIVNESS);

            match renderer.render(&camera, &world.entities(), &mut line_debugger) {
                Ok(_) => {}
                Err(wgpu::SurfaceError::Lost) => renderer.resize(renderer.size),
                Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                Err(wgpu::SurfaceError::Timeout) | Err(wgpu::SurfaceError::Outdated) => (),
            }
        }

        Event::MainEventsCleared => {
            let target_frametime = Duration::from_secs_f32(1.0 / 60.0);
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
