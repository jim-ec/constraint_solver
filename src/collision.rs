mod epa;
mod gjk;
mod sat;

use std::cell::RefCell;

use cgmath::{vec3, InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{
    constraint::Constraint,
    debug,
    frame::Frame,
    geometry::{self, Plane},
    rigid::Rigid,
};

pub fn ground(rigid: &Rigid, past: Frame, polytope: &geometry::Polytope) -> Vec<Constraint> {
    let mut constraints = Vec::new();

    for &vertex in &polytope.vertices {
        let position = rigid.frame().act(vertex);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = position - past.act(rigid.frame().inverse().act(position));
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(Constraint {
            rigid: 0,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}

impl Rigid {
    #[allow(dead_code)]
    pub fn gjk(&self, other: &Rigid, polytope: &geometry::Polytope) -> Option<gjk::Tetrahedron> {
        let mut direction =
            -polytope.minkowski_support((&self.frame(), &other.frame()), Vector3::unit_x());
        let mut simplex = gjk::Simplex::Point(-direction);

        loop {
            let support = polytope.minkowski_support((&self.frame(), &other.frame()), direction);

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
    pub fn epa(&self, other: &Rigid, polytope: &geometry::Polytope) -> Option<epa::Collision> {
        let simplex = self.gjk(other, polytope)?;

        let mut expanding_polytope = epa::Polytope::new(simplex);

        loop {
            let minimal_face = Plane::from_points(
                expanding_polytope.face_vertices(expanding_polytope.minimal_face()),
            );
            let support =
                polytope.minkowski_support((&self.frame(), &other.frame()), minimal_face.normal);

            if polytope.vertices.contains(&support) {
                break;
            }

            expanding_polytope.expand(support);
        }

        let minimal_face =
            Plane::from_points(expanding_polytope.face_vertices(expanding_polytope.minimal_face()));
        Some(epa::Collision {
            normal: minimal_face.normal,
            depth: minimal_face.displacement,
        })
    }

    pub fn sat(
        &self,
        other: &Rigid,
        polytope: &geometry::Polytope,
        #[allow(unused)] debug: &mut debug::DebugLines,
    ) -> bool {
        let self_face_query = sat::face_axes_separation((self, other), polytope);
        if self_face_query.0 >= 0.0 {
            return false;
        }

        let other_face_query = sat::face_axes_separation((other, self), polytope);
        if other_face_query.0 >= 0.0 {
            return false;
        }

        let edge_query = sat::edge_axes_separation((self, other), polytope, debug);
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
