pub mod integrate;

use cgmath::{vec3, InnerSpace, Vector3};
use itertools::Itertools;

use crate::frame::Frame;

#[derive(Debug, Clone, Copy)]
pub struct Plane {
    pub normal: Vector3<f64>,
    pub displacement: f64,
}

impl Plane {
    /// Construct a plane from three points.
    pub fn from_points(points: [Vector3<f64>; 3]) -> Plane {
        let normal = (points[1] - points[0])
            .cross(points[2] - points[0])
            .normalize();
        Plane {
            normal,
            displacement: normal.dot(points[0]),
        }
    }

    /// Construct a plane from a point and a normal vector.
    pub fn from_point_normal(point: Vector3<f64>, normal: Vector3<f64>) -> Plane {
        let mut displacement = point.project_on(normal).magnitude();
        if point.dot(normal) < 0.0 {
            displacement *= -1.0;
        }
        Plane {
            normal,
            displacement,
        }
    }

    /// Compute the distance of the plane to an arbitrary vector.
    pub fn distance(self, point: Vector3<f64>) -> f64 {
        self.normal.dot(point) - self.displacement
    }

    /// Project a vector onto the plane.
    #[allow(dead_code)]
    pub fn project(self, point: Vector3<f64>) -> Vector3<f64> {
        point - self.distance(point) * self.normal
    }

    /// The constant part of this plane's equation.
    pub fn constant(self) -> f64 {
        -self.displacement
    }
}

/// A convex polytope. The surface is assumed to form a manifold.
#[derive(Debug, Clone)]
pub struct Polytope {
    pub vertices: Vec<Vector3<f64>>,

    /// Edges indexing vertices.
    pub edges: Vec<(usize, usize)>,

    /// Convex polygons indexing vertices.
    /// Vertices sharing a face are assumed to be co-planar.
    pub faces: Vec<Vec<usize>>,
}

impl Polytope {
    pub fn new_cube() -> Self {
        Self {
            vertices: vec![
                vec3(-0.5, -0.5, -0.5),
                vec3(0.5, -0.5, -0.5),
                vec3(-0.5, 0.5, -0.5),
                vec3(0.5, 0.5, -0.5),
                vec3(-0.5, -0.5, 0.5),
                vec3(0.5, -0.5, 0.5),
                vec3(-0.5, 0.5, 0.5),
                vec3(0.5, 0.5, 0.5),
            ],
            edges: vec![
                (0, 1),
                (1, 3),
                (3, 2),
                (2, 0),
                (4, 5),
                (5, 7),
                (7, 6),
                (6, 4),
                (0, 4),
                (1, 5),
                (3, 7),
                (2, 6),
            ],
            faces: vec![
                vec![0, 2, 3, 1],
                vec![4, 5, 7, 6],
                vec![4, 0, 1, 5],
                vec![5, 1, 3, 7],
                vec![7, 3, 2, 6],
                vec![6, 2, 0, 4],
            ],
        }
    }

    pub fn new_unit_cube() -> Self {
        Self {
            vertices: vec![
                vec3(0.0, 0.0, 0.0),
                vec3(1.0, 0.0, 0.0),
                vec3(0.0, 1.0, 0.0),
                vec3(1.0, 1.0, 0.0),
                vec3(0.0, 0.0, 1.0),
                vec3(1.0, 0.0, 1.0),
                vec3(0.0, 1.0, 1.0),
                vec3(1.0, 1.0, 1.0),
            ],
            edges: vec![
                (0, 1),
                (1, 3),
                (3, 2),
                (2, 0),
                (4, 5),
                (5, 7),
                (7, 6),
                (6, 4),
                (0, 4),
                (1, 5),
                (3, 7),
                (2, 6),
            ],
            faces: vec![
                vec![0, 2, 3, 1],
                vec![4, 5, 7, 6],
                vec![4, 0, 1, 5],
                vec![5, 1, 3, 7],
                vec![7, 3, 2, 6],
                vec![6, 2, 0, 4],
            ],
        }
    }

    /// An iterator over the polytope's faces, tessellated into triangles.
    /// Co-linear vertices result in degenerate triangles.
    pub fn triangles(&self) -> impl Iterator<Item = (usize, usize, usize)> + '_ {
        self.faces
            .iter()
            .filter_map(|polygon| {
                let mut polygon = polygon.iter().copied();
                let emantating_vertex = polygon.next()?;
                Some(
                    polygon
                        .tuple_windows()
                        .map(move |(v0, v1)| (emantating_vertex, v0, v1)),
                )
            })
            .flatten()
    }

    /// An iterator over the planes this polytope's faces generate.
    /// Since faces with less than three vertices are skipped, an index is also given
    /// to still be able to reference the generating faces.
    pub fn planes(&self) -> impl Iterator<Item = (usize, Plane)> + '_ {
        self.faces
            .iter()
            .enumerate()
            .filter(|(_, face)| face.len() >= 3)
            .map(|(i, face)| {
                let points = [face[0], face[1], face[2]].map(|i| self.vertices[i]);
                (i, Plane::from_points(points))
            })
    }

    // TODO: Remove `frame` parameter, `direction` has to be in local space?
    pub fn support(&self, frame: &Frame, direction: Vector3<f64>) -> Vector3<f64> {
        self.vertices
            .iter()
            .copied()
            .map(|vertex| frame.act(vertex))
            .total_max_by_key(|vertex| vertex.dot(direction))
            .unwrap()
    }

    pub fn minkowski_support(
        &self,
        frames: (&Frame, &Frame),
        direction: Vector3<f64>,
    ) -> Vector3<f64> {
        self.support(frames.0, direction) - self.support(frames.1, -direction)
    }

    pub fn rigid_metrics(&self, density: f64) -> integrate::RigidMetrics {
        integrate::rigid_metrics(self, density)
    }
}

trait CustomIterTools {
    type Item;
    fn total_max_by_key<T: TotalCmp, F: Fn(&Self::Item) -> T>(self, f: F) -> Option<Self::Item>;
}

impl<I: Iterator> CustomIterTools for I {
    type Item = I::Item;
    fn total_max_by_key<T: TotalCmp, F: Fn(&Self::Item) -> T>(self, f: F) -> Option<Self::Item> {
        self.max_by(|a, b| f(a).total_cmp(&f(b)))
    }
}

trait TotalCmp {
    fn total_cmp(&self, other: &Self) -> std::cmp::Ordering;
}

impl TotalCmp for f32 {
    fn total_cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.total_cmp(other)
    }
}

impl TotalCmp for f64 {
    fn total_cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.total_cmp(other)
    }
}
