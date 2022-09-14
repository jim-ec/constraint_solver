use std::rc::Rc;

use lerp::Lerp;
use winit::window::Window;

use crate::{camera, entity, mesh, spatial};

const DEPTH_FORMAT: wgpu::TextureFormat = wgpu::TextureFormat::Depth24Plus;
const SAMPLES: u32 = 4;
const CAMERA_RESPONSIVNESS: f64 = 0.5;

pub struct Renderer {
    surface: wgpu::Surface,
    format: wgpu::TextureFormat,
    pub device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    pub size: winit::dpi::PhysicalSize<u32>,
    camera_uniform_bind_group: wgpu::BindGroup,
    pipeline: wgpu::RenderPipeline,
    pub mesh_uniform_bind_group_layout: wgpu::BindGroupLayout,
    depth_texture: wgpu::Texture,
    color_texture: Option<wgpu::Texture>,
    camera_uniform_buffer: wgpu::Buffer,
    camera: camera::Camera,
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
            label: Some("Camera Uniform Buffer"),
            size: std::mem::size_of::<camera::CameraUniforms>() as wgpu::BufferAddress,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let camera_uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("Camera Uniforms Layout"),
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
            label: Some("Camera Uniforms"),
            layout: &camera_uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: camera_uniform_buffer.as_entire_binding(),
            }],
        });

        let mesh_uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("Mesh Uniforms Layout"),
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

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Render Pipeline Layout"),
            bind_group_layouts: &[
                &camera_uniform_bind_group_layout,
                &mesh_uniform_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let depth_texture = device.create_texture(
            &(wgpu::TextureDescriptor {
                label: Some("Depth Texture"),
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
            label: Some("Shader"),
            source: wgpu::ShaderSource::Wgsl(
                std::fs::read_to_string("shaders/shader.wgsl")
                    .expect("Cannot read shader file")
                    .into(),
            ),
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Render Pipeline"),
            layout: Some(&pipeline_layout),
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

        Ok(Self {
            surface,
            format: swapchain_format,
            device,
            queue,
            config,
            size,
            camera_uniform_bind_group,
            pipeline,
            mesh_uniform_bind_group_layout,
            depth_texture,
            color_texture,
            camera_uniform_buffer,
            camera: camera::Camera::initial(),
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

        if SAMPLES > 1 {
            self.color_texture = Some(self.device.create_texture(&wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width: size.width,
                    height: size.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: SAMPLES,
                dimension: wgpu::TextureDimension::D2,
                format: self.format,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            }))
        }
    }

    pub fn render(
        &mut self,
        camera: &camera::Camera,
        entity: &entity::Entity,
    ) -> Result<(), wgpu::SurfaceError> {
        let output = self.surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        {
            let mut encoder = self
                .device
                .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                    label: Some("Render Encoder"),
                });

            self.camera.orbit = self.camera.orbit.lerp(camera.orbit, CAMERA_RESPONSIVNESS);
            self.camera.tilt = self.camera.tilt.lerp(camera.tilt, CAMERA_RESPONSIVNESS);
            self.camera.distance = self
                .camera
                .distance
                .lerp(camera.distance, CAMERA_RESPONSIVNESS);

            self.queue.write_buffer(
                &self.camera_uniform_buffer,
                0,
                bytemuck::cast_slice(&[self
                    .camera
                    .uniforms(self.size.width as f64 / self.size.height as f64)]),
            );

            let color_texture_view = self
                .color_texture
                .as_ref()
                .map(|color_texture| color_texture.create_view(&Default::default()));

            let depth_texture_view = self.depth_texture.create_view(&Default::default());

            encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: color_texture_view.as_ref().unwrap_or(&view),
                    resolve_target: color_texture_view.as_ref().and(Some(&view)),
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
                    view: &depth_texture_view,
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

        let mut spatial_meshes = vec![];
        Self::gather_meshes(entity, spatial::Spatial::identity(), &mut spatial_meshes);
        for (spatial, mesh) in &spatial_meshes {
            let mut encoder = self.device.create_command_encoder(&Default::default());

            let color_texture_view = self
                .color_texture
                .as_ref()
                .map(|color_texture| color_texture.create_view(&Default::default()));

            let depth_texture_view = self.depth_texture.create_view(&Default::default());

            {
                let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        view: color_texture_view.as_ref().unwrap_or(&view),
                        resolve_target: color_texture_view.as_ref().and(Some(&view)),
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Load,
                            store: true,
                        },
                    })],
                    depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                        view: &depth_texture_view,
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

                self.queue.write_buffer(
                    &mesh.uniform_buffer,
                    0,
                    bytemuck::cast_slice(&[mesh.uniforms(spatial)]),
                );
                render_pass.set_bind_group(1, &mesh.bind_group, &[]);
                render_pass.set_vertex_buffer(0, mesh.vertex_position_buffer.slice(..));
                render_pass.draw(0..mesh.vertex_count as u32, 0..1);
            }

            self.queue.submit(std::iter::once(encoder.finish()));
        }

        output.present();

        Ok(())
    }

    fn gather_meshes(
        entity: &entity::Entity,
        spatial: spatial::Spatial,
        spatial_meshes: &mut Vec<(spatial::Spatial, Rc<mesh::Mesh>)>,
    ) {
        let spatial = spatial.compose(&entity.spatial);

        for mesh in &entity.meshes {
            spatial_meshes.push((spatial, Rc::clone(mesh)));
        }

        for entity in &entity.sub_entities {
            Self::gather_meshes(entity, spatial, spatial_meshes);
        }
    }
}
