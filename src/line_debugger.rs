use cgmath::Vector3;
use itertools::Itertools;

use crate::renderer;

const MAX_VERTEX_COUNT: usize = 1024;

pub struct LineDebugger {
    vertices: Vec<DebugLineVertex>,
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

impl LineDebugger {
    #[allow(dead_code)]
    pub fn debug_lines(&mut self, line: Vec<Vector3<f32>>, color: Vector3<f32>) {
        for (p1, p2) in line.into_iter().tuple_windows() {
            self.vertices.push(DebugLineVertex {
                position: p1,
                color,
            });
            self.vertices.push(DebugLineVertex {
                position: p2,
                color,
            });
        }
        assert!(
            self.vertices.len() < MAX_VERTEX_COUNT,
            "Exceeded maximal debug line vertex count {MAX_VERTEX_COUNT}"
        );
    }

    pub fn new(renderer: &renderer::Renderer) -> Self {
        let buffer = renderer.device.create_buffer(&wgpu::BufferDescriptor {
            label: None,
            size: (MAX_VERTEX_COUNT * std::mem::size_of::<DebugLineVertex>())
                as wgpu::BufferAddress,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let shader = renderer
            .device
            .create_shader_module(wgpu::ShaderModuleDescriptor {
                label: None,
                source: wgpu::ShaderSource::Wgsl(
                    std::fs::read_to_string("shaders/line.wgsl")
                        .expect("Cannot read shader file")
                        .into(),
                ),
            });

        let pipeline = renderer
            .device
            .create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: None,
                layout: Some(&renderer.device.create_pipeline_layout(
                    &wgpu::PipelineLayoutDescriptor {
                        bind_group_layouts: &[&renderer.camera_uniform_bind_group_layout],
                        ..Default::default()
                    },
                )),
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
                        format: renderer.swapchain_format,
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

        Self {
            vertices: vec![],
            buffer,
            pipeline,
        }
    }

    pub fn render(&mut self, renderer: &renderer::Renderer, view: &wgpu::TextureView) {
        renderer.queue.write_buffer(
            &self.buffer,
            0,
            bytemuck::cast_slice(self.vertices.as_slice()),
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
        render_pass.draw(0..self.vertices.len() as u32, 0..1);

        drop(render_pass);

        renderer.queue.submit(std::iter::once(encoder.finish()));

        self.vertices.clear();
    }
}
