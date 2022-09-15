use cgmath::Vector3;
use geometric_algebra::{
    motion,
    pga3::{Branch, Flat, Line, Origin, Plane, Point, Translator},
    project, Inverse, LeftContraction, OuterProduct, Reversal, RightContraction, Transformation,
};
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
    position: Point,
    color: Vector3<f32>,
}

unsafe impl bytemuck::Pod for DebugLineVertex {}
unsafe impl bytemuck::Zeroable for DebugLineVertex {}

impl LineDebugger {
    pub fn debug(&mut self, line: Vec<Point>, color: Vector3<f32>) {
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

    #[allow(dead_code)]
    pub fn debug_point(&mut self, point: Point, color: Vector3<f32>) {
        let d = 0.1;
        let tx = Translator::new(d, 0.0, 0.0);
        let ty = Translator::new(0.0, d, 0.0);
        let tz = Translator::new(0.0, 0.0, d);

        self.debug(
            vec![
                tx.transformation(point),
                tx.reversal().transformation(point),
            ],
            color,
        );
        self.debug(
            vec![
                ty.transformation(point),
                ty.reversal().transformation(point),
            ],
            color,
        );
        self.debug(
            vec![
                tz.transformation(point),
                tz.reversal().transformation(point),
            ],
            color,
        );
    }

    #[allow(dead_code)]
    pub fn debug_line(&mut self, line: Line, color: Vector3<f32>) {
        let d = 10.0;
        let branch: Branch = line.into();

        let motor = motion(
            Origin::new(),
            line.left_contraction(Origin::new()).outer_product(line),
        ) * motion(Branch::new(1.0, 0.0, 0.0), branch);

        self.debug(
            vec![
                motor.transformation(Point::at(-d, 0.0, 0.0)),
                motor.transformation(Point::at(d, 0.0, 0.0)),
            ],
            color,
        )
    }

    #[allow(dead_code)]
    pub fn debug_plane(&mut self, plane: Plane, color: Vector3<f32>) {
        let d = 1.0;

        let p = Origin::new()
            .right_contraction(plane.inverse())
            .outer_product(plane);

        let flat: Flat = plane.into();

        let motor = motion(Origin::new(), p) * motion(Flat::new(0.0, 0.0, 1.0), flat);

        self.debug(
            vec![
                motor.transformation(Point::at(d, d, 0.0)),
                motor.transformation(Point::at(-d, d, 0.0)),
                motor.transformation(Point::at(-d, -d, 0.0)),
                motor.transformation(Point::at(d, -d, 0.0)),
                motor.transformation(Point::at(d, d, 0.0)),
            ],
            color,
        )
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
                depth_stencil: Some(wgpu::DepthStencilState {
                    format: renderer::DEPTH_FORMAT,
                    depth_write_enabled: true,
                    // depth_compare: wgpu::CompareFunction::LessEqual,
                    depth_compare: wgpu::CompareFunction::Always,
                    stencil: Default::default(),
                    bias: Default::default(),
                }),
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
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: &renderer.depth_texture_view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: true,
                }),
                stencil_ops: None,
            }),
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
