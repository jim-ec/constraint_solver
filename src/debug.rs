use cgmath::Vector3;
use itertools::Itertools;

use crate::renderer;

const MAX_VERTEX_COUNT: usize = 4096;

#[derive(Default)]
pub struct DebugLines {
    vertices: Vec<DebugLineVertex>,
}

pub struct LineDebugger {
    buffer: wgpu::Buffer,
    pipeline: wgpu::RenderPipeline,
}

#[repr(C, align(16))]
#[derive(Debug, Clone, Copy)]
struct DebugLineVertex {
    position: Vector3<f32>,
    color: Vector3<f32>,
}

unsafe impl bytemuck::Pod for DebugLineVertex {}
unsafe impl bytemuck::Zeroable for DebugLineVertex {}

impl DebugLines {
    #[allow(dead_code)]
    pub fn line(&mut self, line: Vec<Vector3<f64>>, color: Vector3<f32>) {
        for (p1, p2) in line.into_iter().map(|p| p.cast().unwrap()).tuple_windows() {
            self.vertices.push(DebugLineVertex {
                position: p1,
                color,
            });
            self.vertices.push(DebugLineVertex {
                position: p2,
                color,
            });
        }
    }

    #[allow(dead_code)]
    pub fn point(&mut self, point: Vector3<f64>, color: Vector3<f32>) {
        const D: f32 = 0.5;
        let point: Vector3<f32> = point.cast().unwrap();
        self.vertices.extend([
            DebugLineVertex {
                position: point - D * Vector3::unit_x(),
                color,
            },
            DebugLineVertex {
                position: point + D * Vector3::unit_x(),
                color,
            },
            DebugLineVertex {
                position: point - D * Vector3::unit_y(),
                color,
            },
            DebugLineVertex {
                position: point + D * Vector3::unit_y(),
                color,
            },
            DebugLineVertex {
                position: point - D * Vector3::unit_z(),
                color,
            },
            DebugLineVertex {
                position: point + D * Vector3::unit_z(),
                color,
            },
        ]);
    }

    #[deprecated]
    pub fn clear(&mut self) {
        self.vertices.clear();
    }
}

impl LineDebugger {
    pub fn new(
        device: &wgpu::Device,
        swapchain_format: wgpu::TextureFormat,
        camera_uniform_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: None,
            size: (MAX_VERTEX_COUNT * std::mem::size_of::<DebugLineVertex>())
                as wgpu::BufferAddress,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: None,
            source: wgpu::ShaderSource::Wgsl(
                std::fs::read_to_string("shaders/line.wgsl")
                    .expect("Cannot read shader file")
                    .into(),
            ),
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: None,
            layout: Some(
                &device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                    bind_group_layouts: &[camera_uniform_bind_group_layout],
                    ..Default::default()
                }),
            ),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[wgpu::VertexBufferLayout {
                    array_stride: std::mem::size_of::<DebugLineVertex>() as wgpu::BufferAddress,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[
                        wgpu::VertexAttribute {
                            offset: memoffset::offset_of!(DebugLineVertex, position)
                                as wgpu::BufferAddress,
                            shader_location: 0,
                            format: wgpu::VertexFormat::Float32x4,
                        },
                        wgpu::VertexAttribute {
                            offset: memoffset::offset_of!(DebugLineVertex, color)
                                as wgpu::BufferAddress,
                            shader_location: 1,
                            format: wgpu::VertexFormat::Float32x3,
                        },
                    ],
                }],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: swapchain_format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::LineList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            multisample: wgpu::MultisampleState {
                count: renderer::SAMPLES,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            depth_stencil: None,
            multiview: None,
        });

        Self { buffer, pipeline }
    }

    pub fn render(
        &self,
        debug_lines: &DebugLines,
        renderer: &renderer::Renderer,
        view: &wgpu::TextureView,
    ) {
        if debug_lines.vertices.len() >= MAX_VERTEX_COUNT {
            println!("Exceeded maximal debug line vertex count {MAX_VERTEX_COUNT}")
        }
        let count = debug_lines.vertices.len().min(MAX_VERTEX_COUNT);
        renderer.queue.write_buffer(
            &self.buffer,
            0,
            bytemuck::cast_slice(&debug_lines.vertices[0..count]),
        );

        let mut encoder = renderer.device.create_command_encoder(&Default::default());

        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: renderer.texture_view(view),
                resolve_target: renderer.resolve_target(view),
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: true,
                },
            })],
            ..Default::default()
        });

        render_pass.set_pipeline(&self.pipeline);
        render_pass.set_bind_group(0, &renderer.camera_uniform_bind_group, &[]);
        render_pass.set_vertex_buffer(0, self.buffer.slice(..));
        render_pass.draw(0..count as u32, 0..1);

        drop(render_pass);

        renderer.queue.submit(std::iter::once(encoder.finish()));
    }
}
