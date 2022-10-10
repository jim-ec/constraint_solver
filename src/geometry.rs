use cgmath::{vec3, InnerSpace, Vector3};
use itertools::Itertools;

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
    pub fn project(self, point: Vector3<f64>) -> Vector3<f64> {
        point - self.distance(point) * self.normal
    }
}

/// A convex polytope. The surface is assumed to form a manifold.
#[derive(Debug, Clone)]
pub struct Polytope {
    pub vertices: Vec<Vector3<f64>>,

    /// Edges indexing vertices
    pub edges: Vec<(usize, usize)>,

    /// Convex polygons indexing vertices
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

    /// An iterator over the polytopes faces, tessellated into triangles.
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
}
