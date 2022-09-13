use std::{
    f64::consts::TAU,
    time::{Duration, Instant},
};
use winit::{
    event::*,
    event_loop::{ControlFlow, EventLoop},
    window::WindowBuilder,
};

use crate::{camera, renderer, world};

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

    let mut world = world::World::new(&renderer);
    let mut camera = camera::Camera::initial();

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
                camera.orbit += 0.003 * delta.x;
                camera.tilt += 0.003 * delta.y;
                camera.clamp_tilt();
            }

            WindowEvent::TouchpadMagnify { delta, .. } => {
                camera.distance *= 1.0 - delta;
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
                let mut delta_orbit = initial.orbit - camera.orbit;
                delta_orbit %= TAU;
                if delta_orbit > TAU / 2.0 {
                    delta_orbit -= TAU;
                } else if delta_orbit < -TAU / 2.0 {
                    delta_orbit += TAU;
                }
                camera = camera::Camera {
                    orbit: camera.orbit + delta_orbit,
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
                time.duration_since(time_start).as_secs_f64(),
                delta_time.as_secs_f64(),
            );

            match renderer.render(&camera, &world.entity()) {
                Ok(_) => {}
                Err(wgpu::SurfaceError::Lost) => renderer.resize(renderer.size),
                Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                Err(wgpu::SurfaceError::Timeout) | Err(wgpu::SurfaceError::Outdated) => (),
            }
        }

        Event::MainEventsCleared => {
            let target_frametime = Duration::from_secs_f64(1.0 / 60.0);
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
