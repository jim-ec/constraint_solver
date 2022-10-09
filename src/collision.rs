use std::cell::RefCell;

use cgmath::{vec3, InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{constraint::Constraint, debug, rigid::Rigid};

pub const CUBE_VERTICES: [Vector3<f64>; 8] = [
    vec3(-0.5, -0.5, -0.5),
    vec3(0.5, -0.5, -0.5),
    vec3(-0.5, 0.5, -0.5),
    vec3(0.5, 0.5, -0.5),
    vec3(-0.5, -0.5, 0.5),
    vec3(0.5, -0.5, 0.5),
    vec3(-0.5, 0.5, 0.5),
    vec3(0.5, 0.5, 0.5),
];

const CUBE_FACE_NORMALS: [Vector3<f64>; 6] = [
    vec3(1.0, 0.0, 0.0),
    vec3(-1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, -1.0, 0.0),
    vec3(0.0, 0.0, 1.0),
    vec3(0.0, 0.0, -1.0),
];

const CUBE_EDGES: [(usize, usize); 12] = [
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
];

pub fn ground<'a>(rigid: &'a RefCell<&'a mut Rigid>) -> Vec<Constraint> {
    let mut constraints = Vec::new();

    for vertex in CUBE_VERTICES {
        let position = rigid.borrow().frame.act(vertex);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = rigid.borrow().delta(position);
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(Constraint {
            rigid,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}

impl Rigid {
    fn support(&self, dir: Vector3<f64>) -> Vector3<f64> {
        CUBE_VERTICES
            .into_iter()
            .map(|p| self.frame.act(p))
            .max_by(|a, b| a.dot(dir).total_cmp(&b.dot(dir)))
            .unwrap()
    }

    fn minkowski_support(&self, other: &Rigid, direction: Vector3<f64>) -> Vector3<f64> {
        self.support(direction) - other.support(-direction)
    }

    #[allow(dead_code)]
    pub fn gjk(&self, other: &Rigid) -> Option<Tetrahedron> {
        let mut direction = -self.minkowski_support(other, Vector3::unit_x());
        let mut simplex = Simplex::Point(-direction);

        loop {
            let support = self.minkowski_support(other, direction);

            if !same_direction(direction, support) {
                return None;
            }

            match simplex.enclose(support) {
                Ok(simplex) => return Some(simplex),
                Err((next_simplex, next_direction)) => {
                    simplex = next_simplex;
                    direction = next_direction;
                }
            };
        }
    }

    #[allow(dead_code)]
    pub fn epa(&self, other: &Rigid) -> Option<Collision> {
        let simplex = self.gjk(other)?;

        let mut polytope = Polytope::new(simplex);

        loop {
            let minimal_face = polytope.face_vertices(polytope.minimal_face());
            let normal = plane::normal(minimal_face);
            let support = self.minkowski_support(other, normal);

            if polytope.vertices.contains(&support) {
                break;
            }

            polytope.expand(support);
        }

        let minimal_face = polytope.face_vertices(polytope.minimal_face());
        let normal = plane::normal(minimal_face);
        let depth = plane::distance(minimal_face);

        Some(Collision { normal, depth })
    }
}

/// Simplices up to 3-D.
/// For GJK to work, the invariant that points preceding within the simplex tuple were more recently added
/// to the simplex must be upheld.
#[derive(Debug, Clone, Copy)]
enum Simplex {
    Point(Vector3<f64>),
    Line(Vector3<f64>, Vector3<f64>),
    Triangle(Vector3<f64>, Vector3<f64>, Vector3<f64>),
}

type Tetrahedron = (Vector3<f64>, Vector3<f64>, Vector3<f64>, Vector3<f64>);

impl Simplex {
    fn enclose(self, v: Vector3<f64>) -> Result<Tetrahedron, (Self, Vector3<f64>)> {
        match self {
            Simplex::Point(a) => Err(Self::line(v, a)),
            Simplex::Line(a, b) => Err(Self::triangle(v, a, b)),
            Simplex::Triangle(a, b, c) => Self::tetrahedron(v, a, b, c),
        }
    }

    fn line(a: Vector3<f64>, b: Vector3<f64>) -> (Self, Vector3<f64>) {
        let ab = b - a;
        let ao = -a;

        if same_direction(ab, ao) {
            (Simplex::Line(a, b), ab.cross(ao).cross(ab))
        } else {
            (Simplex::Point(a), ao)
        }
    }

    fn triangle(a: Vector3<f64>, b: Vector3<f64>, c: Vector3<f64>) -> (Self, Vector3<f64>) {
        let ab = b - a;
        let ac = c - a;
        let ao = -a;

        let abc = ab.cross(ac);

        if same_direction(abc.cross(ac), ao) {
            if same_direction(ac, ao) {
                (Simplex::Line(a, c), ac.cross(ao).cross(ac))
            } else {
                Self::line(a, b)
            }
        } else if same_direction(ab.cross(abc), ao) {
            Self::line(a, b)
        } else if same_direction(abc, ao) {
            (Simplex::Triangle(a, b, c), abc)
        } else {
            (Simplex::Triangle(a, c, b), -abc)
        }
    }

    fn tetrahedron(
        a: Vector3<f64>,
        b: Vector3<f64>,
        c: Vector3<f64>,
        d: Vector3<f64>,
    ) -> Result<Tetrahedron, (Self, Vector3<f64>)> {
        let ab = b - a;
        let ac = c - a;
        let ad = d - a;
        let ao = -a;

        let abc = ab.cross(ac);
        let acd = ac.cross(ad);
        let adb = ad.cross(ab);

        if same_direction(abc, ao) {
            Err(Self::triangle(a, b, c))
        } else if same_direction(acd, ao) {
            Err(Self::triangle(a, c, d))
        } else if same_direction(adb, ao) {
            Err(Self::triangle(a, d, b))
        } else {
            Ok((a, b, c, d))
        }
    }
}

pub fn same_direction(a: Vector3<f64>, b: Vector3<f64>) -> bool {
    a.dot(b) > 0.0
}

pub struct Collision {
    pub normal: Vector3<f64>,
    pub depth: f64,
}

#[derive(Debug, Clone)]
struct Polytope {
    vertices: Vec<Vector3<f64>>,
    faces: Vec<[usize; 3]>,
}

impl Polytope {
    fn new(simplex: Tetrahedron) -> Self {
        Self {
            vertices: vec![simplex.0, simplex.1, simplex.2, simplex.3],
            faces: vec![[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]],
        }
    }

    fn face_vertices(&self, face: &[usize; 3]) -> [Vector3<f64>; 3] {
        face.map(|i| self.vertices[i])
    }

    fn minimal_face(&self) -> &[usize; 3] {
        self.faces
            .iter()
            .min_by(|f0, f1| {
                let d0 = plane::distance(self.face_vertices(f0));
                let d1 = plane::distance(self.face_vertices(f1));
                d0.total_cmp(&d1)
            })
            .unwrap()
    }

    fn expand(&mut self, p: Vector3<f64>) {
        self.vertices.push(p);

        let mut edges: Vec<[usize; 2]> = vec![];
        let mut faces = vec![];

        for &face in &self.faces {
            let n = plane::normal(self.face_vertices(&face));
            let d = plane::distance(self.face_vertices(&face));
            if n.dot(p - d * n) <= 0.0 {
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

mod plane {
    #![allow(dead_code)]

    use cgmath::{InnerSpace, Vector3};

    /// Compute the normal of a plane.
    pub fn normal(vertices: [Vector3<f64>; 3]) -> Vector3<f64> {
        (vertices[1] - vertices[0])
            .cross(vertices[2] - vertices[0])
            .normalize()
    }

    /// Compute the distance of the plane to the origin.
    pub fn distance(vertices: [Vector3<f64>; 3]) -> f64 {
        normal(vertices).dot(vertices[0])
    }

    /// Compute the distance of the plane to an arbitrary vector.
    pub fn distance_to(n: Vector3<f64>, d: f64, p: Vector3<f64>) -> f64 {
        n.dot(p) - d
    }

    /// Project a vector onto the plane.
    pub fn project(n: Vector3<f64>, d: f64, p: Vector3<f64>) -> Vector3<f64> {
        p - distance_to(n, d, p) * n
    }
}

impl Rigid {
    fn face_axes_separation(&self, other: &Rigid) -> (f64, usize) {
        let mut max_distance = f64::MIN;
        let mut face_index = usize::MAX;

        for (i, normal) in CUBE_FACE_NORMALS.into_iter().enumerate() {
            let support = CUBE_VERTICES
                .into_iter()
                .map(|p| other.frame.act(p))
                .map(|p| self.frame.inverse().act(p))
                .max_by(|a, b| a.dot(-normal).total_cmp(&b.dot(-normal)))
                .unwrap();
            let distance = plane::distance_to(normal, 0.5, support);
            if distance > max_distance {
                max_distance = distance;
                face_index = i;
            }
        }

        (max_distance, face_index)
    }

    fn edge_axes_separation(&self, other: &Rigid) -> (f64, usize, usize) {
        let mut max_distance = f64::MIN;
        let mut edge_index = (usize::MAX, usize::MAX);

        for (i, self_edge_index) in CUBE_EDGES.into_iter().enumerate() {
            let self_edge = self.frame.act(CUBE_VERTICES[self_edge_index.0])
                - self.frame.act(CUBE_VERTICES[self_edge_index.1]);

            for (j, other_edge_index) in CUBE_EDGES.into_iter().enumerate() {
                let other_edge = other.frame.act(CUBE_VERTICES[other_edge_index.0])
                    - other.frame.act(CUBE_VERTICES[other_edge_index.1]);

                let mut axis = self_edge.cross(other_edge).normalize();

                // Keep normal pointing from `self` to `other`.
                if axis.dot(CUBE_VERTICES[self_edge_index.0] - self.frame.act(Vector3::zero()))
                    < 0.0
                {
                    axis = -axis;
                }

                let support = CUBE_VERTICES
                    .into_iter()
                    .map(|p| other.frame.act(p))
                    .map(|p| self.frame.inverse().act(p))
                    .max_by(|a, b| a.dot(-axis).total_cmp(&b.dot(-axis)))
                    .unwrap();
                let distance = plane::distance_to(axis, 0.5, support);
                if distance > max_distance {
                    max_distance = distance;
                    edge_index = (i, j);
                }
            }
        }

        (max_distance, edge_index.0, edge_index.1)
    }

    pub fn sat(&self, other: &Rigid, #[allow(unused)] debug: &mut debug::DebugLines) -> bool {
        let self_face_query = self.face_axes_separation(other);
        if self_face_query.0 >= 0.0 {
            return false;
        }

        let other_face_query = other.face_axes_separation(self);
        if other_face_query.0 >= 0.0 {
            return false;
        }

        let edge_query = self.edge_axes_separation(other);
        if edge_query.0 >= 0.0 {
            return false;
        }

        true
    }
}
