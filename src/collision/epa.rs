use cgmath::{InnerSpace, Vector3};
use itertools::Itertools;

use crate::geometry::Plane;

use super::gjk;

pub struct Collision {
    pub normal: Vector3<f64>,
    pub depth: f64,
}

#[derive(Debug, Clone)]
pub struct Polytope {
    pub vertices: Vec<Vector3<f64>>,
    faces: Vec<[usize; 3]>,
}

impl Polytope {
    pub fn new(simplex: gjk::Tetrahedron) -> Self {
        Self {
            vertices: vec![simplex.0, simplex.1, simplex.2, simplex.3],
            faces: vec![[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]],
        }
    }

    pub fn face_vertices(&self, face: &[usize; 3]) -> [Vector3<f64>; 3] {
        face.map(|i| self.vertices[i])
    }

    pub fn minimal_face(&self) -> &[usize; 3] {
        self.faces
            .iter()
            .min_by(|f0, f1| {
                let p0 = Plane::from_points(self.face_vertices(f0));
                let p1 = Plane::from_points(self.face_vertices(f1));
                p0.displacement.total_cmp(&p1.displacement)
            })
            .unwrap()
    }

    pub fn expand(&mut self, p: Vector3<f64>) {
        self.vertices.push(p);

        let mut edges: Vec<[usize; 2]> = vec![];
        let mut faces = vec![];

        for &face in &self.faces {
            let plane = Plane::from_points(self.face_vertices(&face));
            if plane.normal.dot(p - plane.displacement * plane.normal) <= 0.0 {
                faces.push(face);
            } else {
                for (&e0, &e1) in face.iter().circular_tuple_windows() {
                    // TODO: Are both tests needed?
                    if let Some(index) = edges
                        .iter()
                        .position(|&edge| edge == [e0, e1] || edge == [e1, e0])
                    {
                        edges.remove(index);
                    } else {
                        edges.push([e0, e1])
                    }
                }
            }
        }

        for edge in edges {
            faces.push([edge[0], edge[1], self.vertices.len() - 1]);
        }

        self.faces = faces;
    }
}
