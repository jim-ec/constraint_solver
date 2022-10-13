use crate::{frame::Frame, geometry, renderer};
use cgmath::{Matrix4, Vector3};
use derive_setters::Setters;
use wgpu::util::DeviceExt;

#[derive(Debug, Setters)]
pub struct Mesh {
    pub vertex_position_buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub uniform_buffer: wgpu::Buffer,
    pub vertex_count: usize,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct MeshUniforms {
    transform: Matrix4<f32>,
    color: [f32; 3],
}

unsafe impl bytemuck::Pod for MeshUniforms {}
unsafe impl bytemuck::Zeroable for MeshUniforms {}

impl Mesh {
    pub fn upload_uniforms(&self, queue: &wgpu::Queue, frame: Frame, color: [f32; 3]) {
        queue.write_buffer(
            &self.uniform_buffer,
            0,
            bytemuck::cast_slice(&[MeshUniforms {
                transform: frame.matrix(),
                color,
            }]),
        );
    }

    pub fn from_vertices(renderer: &renderer::Renderer, positions: &[Vector3<f32>]) -> Self {
        let vertex_count = positions.len();

        let vertex_position_buffer =
            renderer
                .device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: None,
                    contents: unsafe {
                        std::slice::from_raw_parts(
                            positions.as_ptr() as *const u8,
                            positions.len() * std::mem::size_of::<Vector3<f32>>(),
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
                    label: None,
                    size: padded_size as wgpu::BufferAddress,
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    mapped_at_creation: false,
                }),
            );
        }

        let bind_group = renderer
            .device
            .create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &renderer.mesh_uniform_bind_group_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                }],
            });

        Self {
            vertex_position_buffer,
            bind_group,
            uniform_buffer,
            vertex_count,
        }
    }

    pub fn from_polytope(renderer: &renderer::Renderer, polytope: &geometry::Polytope) -> Self {
        let mut positions = Vec::new();
        for triangle in polytope.triangles() {
            positions.push(polytope.vertices[triangle.0].cast().unwrap());
            positions.push(polytope.vertices[triangle.1].cast().unwrap());
            positions.push(polytope.vertices[triangle.2].cast().unwrap());
        }
        Mesh::from_vertices(renderer, &positions)
    }
}
