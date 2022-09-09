use std::time::{Duration, Instant};
use winit::{
    event::*,
    event_loop::{ControlFlow, EventLoop},
    window::WindowBuilder,
};

use crate::{game, renderer};

pub async fn run() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    let time_start = Instant::now();
    let mut last_render_time = Instant::now();
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title("WebGPU Tutorial")
        .with_visible(false)
        .build(&event_loop)
        .unwrap();

    let mut renderer = renderer::Renderer::new(&window).await?;

    let mut game = game::Game::new(&renderer);

    event_loop.run(move |event, _, control_flow| match event {
        Event::NewEvents(winit::event::StartCause::Init) => {
            window.set_visible(true);
        }

        Event::WindowEvent { event, .. } => {
            if !game.input(&event) {
                match event {
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
                    _ => {}
                }
            }
        }

        Event::RedrawRequested(..) => {
            let time = Instant::now();
            let delta_time = time.duration_since(last_render_time);
            last_render_time = time;

            game.integrate(
                time.duration_since(time_start).as_secs_f64(),
                delta_time.as_secs_f64(),
            );

            match renderer.render(&game.camera, &game.entity()) {
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
