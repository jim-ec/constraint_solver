use crate::{renderer, shapes::Shape, spatial::Spatial};
use cgmath::Matrix4;
use derive_setters::Setters;
use geometric_algebra::pga3::Point;
use itertools::Itertools;
use wgpu::util::DeviceExt;

#[derive(Debug, Setters)]
pub struct Mesh {
    pub topology: Topology,
    pub fill: Fill,
    pub culling: Culling,
    pub color: [f32; 3],
    pub lit: bool,
    pub vertex_position_buffer: wgpu::Buffer,
    pub vertex_color_buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub uniform_buffer: wgpu::Buffer,
    pub vertex_count: usize,
}

#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]
pub enum Topology {
    Triangles,
    Lines,
    Points,
}

#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]
pub enum Fill {
    Solid,
    Wireframe,
}

#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]
pub enum Culling {
    Front,
    Back,
    None,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct MeshUniforms {
    pub transform: Matrix4<f32>,
    pub color: [f32; 3],
    pub lit: u32,
}

unsafe impl bytemuck::Pod for MeshUniforms {}
unsafe impl bytemuck::Zeroable for MeshUniforms {}

const DEFAULT_VERTEX_COLOR: [f32; 3] = [1.0, 1.0, 1.0];

impl Mesh {
    pub fn upload_uniforms(&self, queue: &wgpu::Queue, spatial: &Spatial) {
        queue.write_buffer(
            &self.uniform_buffer,
            0,
            bytemuck::cast_slice(&[self.uniforms(spatial)]),
        );
    }

    pub fn from_vertices(
        renderer: &renderer::Renderer,
        topology: Topology,
        positions: &[Point],
        colors: &[[f32; 3]],
    ) -> Self {
        let vertex_count = positions.len();
        assert_eq!(vertex_count, colors.len());

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

        let vertex_color_buffer =
            renderer
                .device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("Mesh Vertex Color Buffer"),
                    contents: unsafe {
                        std::slice::from_raw_parts(
                            colors.as_ptr() as *const u8,
                            colors.len() * std::mem::size_of::<[f32; 3]>(),
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
            fill: Fill::Solid,
            culling: Culling::Back,
            topology,
            color: [0.4, 0.4, 0.4],
            lit: true,
            vertex_position_buffer,
            vertex_color_buffer,
            bind_group,
            uniform_buffer,
            vertex_count,
        }
    }

    pub fn from_shape(
        renderer: &renderer::Renderer,
        shape: Shape,
        shape_colors: Option<&[[f32; 3]]>,
    ) -> Self {
        let renderer = renderer;
        let mut positions = Vec::with_capacity(shape.triangles.len() * 3);
        let mut colors = Vec::with_capacity(shape.triangles.len() * 3);
        for triangle in shape.triangles {
            positions.push(shape.points[triangle.0]);
            positions.push(shape.points[triangle.1]);
            positions.push(shape.points[triangle.2]);
            colors.push(
                shape_colors
                    .map(|shape_colors| shape_colors[triangle.0])
                    .unwrap_or(DEFAULT_VERTEX_COLOR),
            );
            colors.push(
                shape_colors
                    .map(|shape_colors| shape_colors[triangle.1])
                    .unwrap_or(DEFAULT_VERTEX_COLOR),
            );
            colors.push(
                shape_colors
                    .map(|shape_colors| shape_colors[triangle.2])
                    .unwrap_or(DEFAULT_VERTEX_COLOR),
            );
        }
        Mesh::from_vertices(renderer, Topology::Triangles, &positions, &colors)
    }

    pub fn from_lines(
        renderer: &renderer::Renderer,
        lines: Vec<Vec<Point>>,
        line_colors: Option<Vec<[f32; 3]>>,
    ) -> Self {
        let mut positions = Vec::new();
        let mut colors = Vec::new();

        let color_iter = line_colors
            .map(|line_colors| Box::new(line_colors.into_iter()) as Box<dyn Iterator<Item = _>>)
            .unwrap_or_else(|| Box::new(std::iter::repeat(DEFAULT_VERTEX_COLOR).take(lines.len())));

        for (line, color) in lines.into_iter().zip_eq(color_iter) {
            for (prev_point, point) in line.into_iter().tuple_windows() {
                positions.push(prev_point);
                positions.push(point);
                colors.push(color);
                colors.push(color);
            }
        }

        Self::from_vertices(renderer, Topology::Lines, &positions, &colors).lit(false)
    }

    pub fn new_grid(renderer: &renderer::Renderer, sections: usize, subsections: usize) -> Self {
        let mut lines = Vec::new();
        let mut colors = Vec::new();
        let color = [1.0, 1.0, 1.0];
        let sub_color = [0.2, 0.2, 0.2];

        for i in 0..sections {
            let x = i as f32 / sections as f32;

            lines.extend([
                vec![Point::at(x, 0.0, 0.0), Point::at(x, 1.0, 0.0)],
                vec![Point::at(0.0, x, 0.0), Point::at(1.0, x, 0.0)],
            ]);
            colors.extend([color, color]);

            for i in 1..subsections {
                let x = x + i as f32 / subsections as f32 / sections as f32;
                lines.extend([
                    vec![Point::at(x, 0.0, 0.0), Point::at(x, 1.0, 0.0)],
                    vec![Point::at(0.0, x, 0.0), Point::at(1.0, x, 0.0)],
                ]);
                colors.extend([sub_color, sub_color]);
            }
        }

        lines.push(vec![
            Point::at(1.0, 0.0, 0.0),
            Point::at(1.0, 1.0, 0.0),
            Point::at(0.0, 1.0, 0.0),
        ]);
        colors.push(color);

        Self::from_lines(renderer, lines, Some(colors))
    }

    pub fn new_axes(renderer: &renderer::Renderer) -> Self {
        Self::from_lines(
            renderer,
            vec![
                vec![Point::origin(), Point::at(1.0, 0.0, 0.0)],
                vec![Point::origin(), Point::at(0.0, 1.0, 0.0)],
                vec![Point::origin(), Point::at(0.0, 0.0, 1.0)],
            ],
            Some(vec![[1.0, 0.2, 0.2], [0.2, 1.0, 0.2], [0.2, 0.2, 1.0]]),
        )
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
            lit: self.lit as u32,
        }
    }
}

pub mod debug {
    use super::Mesh;
    use crate::renderer;
    use crate::shapes;
    use geometric_algebra::pga3::Point;
    use std::rc::Rc;

    pub struct Library {
        point: Rc<Mesh>,
        line: Rc<Mesh>,
        plane: Rc<Mesh>,
    }

    impl Library {
        pub fn new(renderer: &renderer::Renderer) -> Self {
            Self {
                point: Rc::new({
                    let d = 0.1;
                    Mesh::from_lines(
                        renderer,
                        vec![
                            vec![Point::at(-d, 0.0, 0.0), Point::at(d, 0.0, 0.0)],
                            vec![Point::at(0.0, -d, 0.0), Point::at(0.0, d, 0.0)],
                            vec![Point::at(0.0, 0.0, -d), Point::at(0.0, 0.0, d)],
                        ],
                        None,
                    )
                }),
                line: Rc::new({
                    let d = 10.0;
                    Mesh::from_lines(
                        renderer,
                        vec![vec![Point::at(-d, 0.0, 0.0), Point::at(d, 0.0, 0.0)]],
                        None,
                    )
                }),
                plane: Rc::new(Mesh::from_shape(
                    renderer,
                    shapes::Shape {
                        points: vec![
                            Point::at(-1.0, -1.0, 0.0),
                            Point::at(1.0, -1.0, 0.0),
                            Point::at(-1.0, 1.0, 0.0),
                            Point::at(1.0, 1.0, 0.0),
                        ],
                        triangles: vec![shapes::Triangle(0, 1, 2), shapes::Triangle(2, 1, 3)],
                    },
                    None,
                )),
            }
        }

        pub fn point(&self) -> Rc<Mesh> {
            Rc::clone(&self.point)
        }

        pub fn line(&self) -> Rc<Mesh> {
            Rc::clone(&self.line)
        }

        pub fn plane(&self) -> Rc<Mesh> {
            Rc::clone(&self.plane)
        }
    }
}