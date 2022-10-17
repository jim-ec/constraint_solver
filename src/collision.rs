use cgmath::{InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{
    constraint::Constraint,
    debug,
    frame::Frame,
    geometry::{self, Plane, Polytope},
    rigid::Rigid,
};

#[allow(dead_code)]
pub fn ground(rigid: &Rigid, past: Frame, polytope: &geometry::Polytope) -> Vec<Constraint> {
    let mut constraints = Vec::new();

    for &vertex in &polytope.vertices {
        let position = rigid.frame().act(vertex);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = rigid.frame().delta(past, position);
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(Constraint {
            rigid: 0,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}

pub fn sat(
    rigids: (&Rigid, &Rigid),
    polytopes: (&Polytope, &Polytope),
    debug: &mut debug::DebugLines,
) -> bool {
    let a_face_query = face_axes_separation(rigids, polytopes);
    if a_face_query.0 >= 0.0 {
        return true;
    }

    let b_face_query = face_axes_separation(rigids, polytopes);
    if b_face_query.0 >= 0.0 {
        return true;
    }

    let edge_query = edge_axes_separation(rigids, polytopes, debug);
    if edge_query.0 >= 0.0 {
        return true;
    }

    if a_face_query.0 > edge_query.0 && b_face_query.0 > edge_query.0 {
        // face_contact(rigids, (a_face_query, b_face_query), debug);
        debug.line_loop(
            polytopes.0.faces[a_face_query.1]
                .iter()
                .map(|&i| polytopes.0.vertices[i])
                .map(|v| rigids.0.frame().act(v)),
            [0.0, 0.0, 1.0],
        );
    } else {
        let edges = edge_query.1;

        {
            let edge = polytopes.0.edges[edges.0];
            debug.line(
                [
                    rigids.0.frame().act(polytopes.0.vertices[edge.0]),
                    rigids.0.frame().act(polytopes.0.vertices[edge.1]),
                ],
                [0.0, 1.0, 0.0],
            )
        }

        {
            let edge = polytopes.1.edges[edges.1];
            debug.line(
                [
                    rigids.1.frame().act(polytopes.1.vertices[edge.0]),
                    rigids.1.frame().act(polytopes.1.vertices[edge.1]),
                ],
                [0.0, 1.0, 0.0],
            )
        }

        edge_contact(rigids, edge_query);
    }

    false
}

pub fn face_axes_separation(
    rigids: (&Rigid, &Rigid),
    polytopes: (&Polytope, &Polytope),
) -> (f64, usize) {
    let mut max_distance = f64::MIN;
    let mut face_index = usize::MAX;

    for (i, plane) in polytopes.0.planes() {
        let support = polytopes
            .1
            .vertices
            .iter()
            .copied()
            .map(|p| rigids.1.frame().act(p))
            .map(|p| rigids.0.frame().inverse().act(p))
            .max_by(|a, b| a.dot(-plane.normal).total_cmp(&b.dot(-plane.normal)))
            .unwrap();

        let distance = plane.distance(support);
        if distance > max_distance {
            max_distance = distance;
            face_index = i;
        }
    }

    (max_distance, face_index)
}

pub fn edge_axes_separation(
    rigids: (&Rigid, &Rigid),
    polytopes: (&Polytope, &Polytope),
    _debug: &mut debug::DebugLines,
) -> (f64, (usize, usize)) {
    let mut max_distance = f64::MIN;
    let mut edge_indices = (usize::MAX, usize::MAX);

    for ((i_edge, i), (j_edge, j)) in polytopes
        .0
        .edges
        .iter()
        .copied()
        .enumerate()
        .cartesian_product(polytopes.1.edges.iter().copied().enumerate())
    {
        let foot = rigids.0.frame().act(polytopes.0.vertices[i.0]);

        let edges = (
            rigids.0.frame().act(polytopes.0.vertices[i.1]) - foot,
            rigids.1.frame().act(polytopes.1.vertices[j.1])
                - rigids.1.frame().act(polytopes.1.vertices[j.0]),
        );

        let mut axis = edges.0.cross(edges.1).normalize();

        // Keep normal pointing from `self` to `other`.
        if axis.dot(foot - rigids.0.frame().act(Vector3::zero())) < 0.0 {
            axis = -axis;
        }

        let plane = Plane::from_point_normal(polytopes.0.support(&rigids.0.frame(), axis), axis);
        let distance = plane.distance(polytopes.1.support(&rigids.1.frame(), -axis));

        if distance > max_distance {
            max_distance = distance;
            edge_indices = (i_edge, j_edge);
        }
    }

    (max_distance, edge_indices)
}

pub fn edge_contact(_rigids: (&Rigid, &Rigid), _query: (f64, (usize, usize))) {}

pub fn face_contact(
    rigids: (&Rigid, &Rigid),
    queries: ((f64, usize), (f64, usize)),
    debug: &mut debug::DebugLines,
) {
}
