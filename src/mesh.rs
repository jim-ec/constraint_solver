use crate::{renderer, spatial::Spatial};
use cgmath::Matrix4;
use derive_setters::Setters;
use geometric_algebra::pga3::Point;
use wgpu::util::DeviceExt;

#[derive(Debug, Setters)]
pub struct Mesh {
    pub color: [f32; 3],
    pub vertex_position_buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub uniform_buffer: wgpu::Buffer,
    pub vertex_count: usize,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct MeshUniforms {
    pub transform: Matrix4<f32>,
    pub color: [f32; 3],
}

unsafe impl bytemuck::Pod for MeshUniforms {}
unsafe impl bytemuck::Zeroable for MeshUniforms {}

impl Mesh {
    pub fn upload_uniforms(&self, queue: &wgpu::Queue, spatial: &Spatial) {
        queue.write_buffer(
            &self.uniform_buffer,
            0,
            bytemuck::cast_slice(&[self.uniforms(spatial)]),
        );
    }

    pub fn from_vertices(renderer: &renderer::Renderer, positions: &[Point]) -> Self {
        let vertex_count = positions.len();

        let vertex_position_buffer =
            renderer
                .device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("Mesh Vertex Position Buffer"),
                    contents: unsafe {
                        std::slice::from_raw_parts(
                            positions.as_ptr() as *const u8,
                            positions.len() * std::mem::size_of::<Point>(),
                        )
                    },
                    usage: wgpu::BufferUsages::VERTEX,
                });

        let uniform_buffer;
        {
            let unpadded_size = std::mem::size_of::<MeshUniforms>();
            let align_mask = 0xf - 1;
            let padded_size = (unpadded_size + align_mask) & !align_mask;

            uniform_buffer = renderer.device.create_buffer(
                &(wgpu::BufferDescriptor {
                    label: Some("Mesh Uniform Buffer"),
                    size: padded_size as wgpu::BufferAddress,
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    mapped_at_creation: false,
                }),
            );
        }

        let bind_group = renderer
            .device
            .create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("Mesh Uniforms"),
                layout: &renderer.mesh_uniform_bind_group_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                }],
            });

        Self {
            color: [0.4, 0.4, 0.4],
            vertex_position_buffer,
            bind_group,
            uniform_buffer,
            vertex_count,
        }
    }

    pub fn uniforms(&self, spatial: &Spatial) -> MeshUniforms {
        let transform = spatial.matrix();
        let z_up: Matrix4<f32> = [
            [0.0, 0.0, 1.0, 0.0],
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        ]
        .into();

        MeshUniforms {
            transform: z_up * transform,
            color: self.color,
        }
    }

    pub fn from_triangles(
        renderer: &renderer::Renderer,
        points: &[Point],
        triangles: &[(usize, usize, usize)],
    ) -> Self {
        let renderer = renderer;
        let mut positions = Vec::with_capacity(triangles.len() * 3);
        for triangle in triangles {
            positions.push(points[triangle.0]);
            positions.push(points[triangle.1]);
            positions.push(points[triangle.2]);
        }
        Mesh::from_vertices(renderer, &positions)
    }

    pub fn new_cube(renderer: &renderer::Renderer) -> Self {
        Self::from_triangles(
            renderer,
            &[
                Point::at(-0.5, -0.5, -0.5),
                Point::at(-0.5, -0.5, 0.5),
                Point::at(-0.5, 0.5, -0.5),
                Point::at(-0.5, 0.5, 0.5),
                Point::at(0.5, -0.5, -0.5),
                Point::at(0.5, -0.5, 0.5),
                Point::at(0.5, 0.5, -0.5),
                Point::at(0.5, 0.5, 0.5),
            ],
            &[
                (0, 1, 3),
                (0, 3, 2),
                (0, 4, 5),
                (0, 5, 1),
                (0, 6, 4),
                (0, 2, 6),
                (1, 5, 7),
                (1, 7, 3),
                (2, 7, 6),
                (2, 3, 7),
                (4, 7, 5),
                (4, 6, 7),
            ],
        )
    }
}
