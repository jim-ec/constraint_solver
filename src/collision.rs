mod epa;
mod gjk;
mod sat;

use std::cell::RefCell;

use cgmath::{vec3, InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{constraint::Constraint, debug, geometry::Plane, rigid::Rigid};

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
    pub fn gjk(&self, other: &Rigid) -> Option<gjk::Tetrahedron> {
        let mut direction = -self.minkowski_support(other, Vector3::unit_x());
        let mut simplex = gjk::Simplex::Point(-direction);

        loop {
            let support = self.minkowski_support(other, direction);

            if direction.dot(support) <= 0.0 {
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
    pub fn epa(&self, other: &Rigid) -> Option<epa::Collision> {
        let simplex = self.gjk(other)?;

        let mut polytope = epa::Polytope::new(simplex);

        loop {
            let minimal_face = Plane::from_points(polytope.face_vertices(polytope.minimal_face()));
            let support = self.minkowski_support(other, minimal_face.normal);

            if polytope.vertices.contains(&support) {
                break;
            }

            polytope.expand(support);
        }

        let minimal_face = Plane::from_points(polytope.face_vertices(polytope.minimal_face()));
        Some(epa::Collision {
            normal: minimal_face.normal,
            depth: minimal_face.displacement,
        })
    }

    pub fn sat(&self, other: &Rigid, #[allow(unused)] debug: &mut debug::DebugLines) -> bool {
        let self_face_query = sat::face_axes_separation((self, other));
        if self_face_query.0 >= 0.0 {
            return false;
        }

        let other_face_query = sat::face_axes_separation((other, self));
        if other_face_query.0 >= 0.0 {
            return false;
        }

        let edge_query = sat::edge_axes_separation((self, other), debug);
        if edge_query.0 >= 0.0 {
            return false;
        }

        if self_face_query.0 > edge_query.0 && other_face_query.0 > edge_query.0 {
            sat::face_contact((self, other), (self_face_query, other_face_query));
        } else {
            sat::edge_contact((self, other), edge_query);
        }

        true
    }
}
