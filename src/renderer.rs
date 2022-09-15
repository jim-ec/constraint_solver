use winit::window::Window;

use crate::{camera, entity, line_debugger};

pub const DEPTH_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Depth24Plus;
pub const SAMPLES: u32 = 4;

pub struct Renderer {
    surface: wgpu::Surface,
    pub swapchain_format: wgpu::TextureFormat,
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    pub size: winit::dpi::PhysicalSize<u32>,
    pub camera_uniform_bind_group: wgpu::BindGroup,
    pipeline: wgpu::RenderPipeline,
    grid_pipeline: wgpu::RenderPipeline,
    pub camera_uniform_bind_group_layout: wgpu::BindGroupLayout,
    pub mesh_uniform_bind_group_layout: wgpu::BindGroupLayout,
    pub color_texture: Option<wgpu::Texture>,
    pub color_texture_view: Option<wgpu::TextureView>,
    pub depth_texture: wgpu::Texture,
    pub depth_texture_view: wgpu::TextureView,
    camera_uniform_buffer: wgpu::Buffer,
}

impl Renderer {
    pub async fn new(window: &Window) -> Result<Self, Box<dyn std::error::Error>> {
        let size = window.inner_size();
        let instance = wgpu::Instance::new(wgpu::Backends::all());
        let surface = unsafe { instance.create_surface(window) };
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await
            .expect("No GPU available");

        println!("GPU: {}", adapter.get_info().name);
        println!("Render Backend: {:?}", adapter.get_info().backend);

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    features: wgpu::Features::POLYGON_MODE_LINE,
                    limits: wgpu::Limits::default(),
                    label: None,
                },
                None,
            )
            .await
            .unwrap();

        let swapchain_format = *surface
            .get_supported_formats(&adapter)
            .first()
            .expect("Surface is incompatible with the adapter");
        println!("Swapchain format: {swapchain_format:?}");

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: swapchain_format,
            width: size.width,
            height: size.height,
            present_mode: wgpu::PresentMode::Fifo,
        };

        surface.configure(&device, &config);

        let camera_uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: None,
            size: std::mem::size_of::<camera::CameraUniforms>() as wgpu::BufferAddress,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let camera_uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: None,
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX | wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(std::mem::size_of::<
                            camera::CameraUniforms,
                        >()
                            as wgpu::BufferAddress),
                    },
                    count: None,
                }],
            });

        let camera_uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &camera_uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: camera_uniform_buffer.as_entire_binding(),
            }],
        });

        let mesh_uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: None,
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX | wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                }],
            });

        let depth_texture = device.create_texture(
            &(wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width: config.width,
                    height: config.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: SAMPLES,
                dimension: wgpu::TextureDimension::D2,
                format: DEPTH_FORMAT,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            }),
        );

        let color_texture = if SAMPLES > 1 {
            Some(device.create_texture(&wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width: window.inner_size().width,
                    height: window.inner_size().height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: SAMPLES,
                dimension: wgpu::TextureDimension::D2,
                format: swapchain_format,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            }))
        } else {
            None
        };

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: None,
            source: wgpu::ShaderSource::Wgsl(
                std::fs::read_to_string("shaders/shader.wgsl")
                    .expect("Cannot read shader file")
                    .into(),
            ),
        });

        let grid_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: None,
            source: wgpu::ShaderSource::Wgsl(
                std::fs::read_to_string("shaders/grid.wgsl")
                    .expect("Cannot read shader file")
                    .into(),
            ),
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: None,
            layout: Some(
                &device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                    bind_group_layouts: &[
                        &camera_uniform_bind_group_layout,
                        &mesh_uniform_bind_group_layout,
                    ],
                    ..Default::default()
                }),
            ),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[wgpu::VertexBufferLayout {
                    array_stride: std::mem::size_of::<[f32; 4]>() as wgpu::BufferAddress,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &[wgpu::VertexAttribute {
                        offset: 0,
                        shader_location: 0,
                        format: wgpu::VertexFormat::Float32x4,
                    }],
                }],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: swapchain_format,
                    blend: Some(wgpu::BlendState::REPLACE),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            multisample: wgpu::MultisampleState {
                count: SAMPLES,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            depth_stencil: Some(wgpu::DepthStencilState {
                format: DEPTH_FORMAT,
                depth_write_enabled: true,
                depth_compare: wgpu::CompareFunction::LessEqual,
                stencil: Default::default(),
                bias: Default::default(),
            }),
            multiview: None,
        });

        let grid_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: None,
            layout: Some(
                &device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                    bind_group_layouts: &[&camera_uniform_bind_group_layout],
                    ..Default::default()
                }),
            ),
            vertex: wgpu::VertexState {
                module: &grid_shader,
                entry_point: "vs_main",
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &grid_shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: swapchain_format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            multisample: wgpu::MultisampleState {
                count: SAMPLES,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            depth_stencil: Some(wgpu::DepthStencilState {
                format: DEPTH_FORMAT,
                depth_write_enabled: true,
                depth_compare: wgpu::CompareFunction::LessEqual,
                stencil: Default::default(),
                bias: Default::default(),
            }),
            multiview: None,
        });

        Ok(Self {
            surface,
            swapchain_format,
            device,
            queue,
            config,
            size,
            camera_uniform_bind_group,
            pipeline,
            grid_pipeline,
            camera_uniform_bind_group_layout,
            mesh_uniform_bind_group_layout,
            color_texture_view: color_texture
                .as_ref()
                .map(|color_texture| color_texture.create_view(&Default::default())),
            color_texture,
            depth_texture_view: depth_texture.create_view(&Default::default()),
            depth_texture,
            camera_uniform_buffer,
        })
    }

    pub fn resize(&mut self, size: winit::dpi::PhysicalSize<u32>) {
        if size.width == 0 || size.height == 0 {
            return;
        }
        self.size = size;
        self.config.width = size.width;
        self.config.height = size.height;
        self.surface.configure(&self.device, &self.config);

        self.depth_texture = self.device.create_texture(
            &(wgpu::TextureDescriptor {
                label: Some("Depth Texture"),
                size: wgpu::Extent3d {
                    width: self.config.width,
                    height: self.config.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: SAMPLES,
                dimension: wgpu::TextureDimension::D2,
                format: DEPTH_FORMAT,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            }),
        );
        self.depth_texture_view = self.depth_texture.create_view(&Default::default());

        if SAMPLES > 1 {
            let texture = self.device.create_texture(&wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width: size.width,
                    height: size.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: SAMPLES,
                dimension: wgpu::TextureDimension::D2,
                format: self.swapchain_format,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            });
            self.color_texture_view = Some(texture.create_view(&Default::default()));
            self.color_texture = Some(texture);
        }
    }

    pub fn render(
        &mut self,
        camera: &camera::Camera,
        entities: &[entity::Entity],
        line_debugger: &mut line_debugger::LineDebugger,
    ) -> Result<(), wgpu::SurfaceError> {
        let surface_texture = self.surface.get_current_texture()?;
        let view = surface_texture
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        self.clear_surface(&view);

        self.queue.write_buffer(
            &self.camera_uniform_buffer,
            0,
            bytemuck::cast_slice(&[
                camera.uniforms(self.size.width as f32 / self.size.height as f32)
            ]),
        );

        for entity in entities {
            self.render_entity(&view, entity);
        }

        self.render_grid(&view);

        line_debugger.render(self, &view);

        surface_texture.present();

        Ok(())
    }

    fn clear_surface(&mut self, view: &wgpu::TextureView) {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });

        encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: self.texture_view(view),
                resolve_target: self.resolve_target(view),
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r: 0.01,
                        g: 0.01,
                        b: 0.01,
                        a: 1.0,
                    }),
                    store: true,
                },
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: &self.depth_texture_view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Clear(1.0),
                    store: true,
                }),
                stencil_ops: None,
            }),
            ..Default::default()
        });

        self.queue.submit(std::iter::once(encoder.finish()));
    }

    fn render_entity(&self, view: &wgpu::TextureView, entity: &entity::Entity) {
        let spatial = &entity.spatial;
        for mesh in &entity.meshes {
            let mut encoder = self.device.create_command_encoder(&Default::default());

            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: self.texture_view(view),
                    resolve_target: self.resolve_target(view),
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Load,
                        store: true,
                    },
                })],
                depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                    view: &self.depth_texture_view,
                    depth_ops: Some(wgpu::Operations {
                        load: wgpu::LoadOp::Load,
                        store: true,
                    }),
                    stencil_ops: None,
                }),
                ..Default::default()
            });

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(0, &self.camera_uniform_bind_group, &[]);

            mesh.upload_uniforms(&self.queue, spatial);
            render_pass.set_bind_group(1, &mesh.bind_group, &[]);
            render_pass.set_vertex_buffer(0, mesh.vertex_position_buffer.slice(..));
            render_pass.draw(0..mesh.vertex_count as u32, 0..1);

            drop(render_pass);

            self.queue.submit(std::iter::once(encoder.finish()));
        }
    }

    fn render_grid(&self, view: &wgpu::TextureView) {
        let mut encoder = self.device.create_command_encoder(&Default::default());

        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: self.texture_view(view),
                resolve_target: self.resolve_target(view),
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: true,
                },
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: &self.depth_texture_view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: true,
                }),
                stencil_ops: None,
            }),
            ..Default::default()
        });

        render_pass.set_pipeline(&self.grid_pipeline);
        render_pass.set_bind_group(0, &self.camera_uniform_bind_group, &[]);
        render_pass.draw(0..6, 0..1);

        drop(render_pass);

        self.queue.submit(std::iter::once(encoder.finish()));
    }

    pub fn texture_view<'a>(&'a self, view: &'a wgpu::TextureView) -> &'a wgpu::TextureView {
        self.color_texture_view.as_ref().unwrap_or(view)
    }

    pub fn resolve_target<'a>(
        &'a self,
        view: &'a wgpu::TextureView,
    ) -> Option<&'a wgpu::TextureView> {
        self.color_texture_view.as_ref().and(Some(view))
    }
}
