use cgmath::{InnerSpace, Vector3};
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
        let position = rigid.frame() * vertex;
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
    frames: (Frame, Frame),
    polytopes: (&Polytope, &Polytope),
    debug: &mut debug::DebugLines,
) -> bool {
    let a_face_query = face_axes_separation(frames, polytopes);
    if a_face_query.0 >= 0.0 {
        return true;
    }

    // let b_face_query = face_axes_separation(frames, polytopes);
    // if b_face_query.0 >= 0.0 {
    //     return true;
    // }

    // let edge_query = edge_axes_separation(frames, polytopes, debug);
    // if edge_query.0 >= 0.0 {
    //     return true;
    // }

    // let minimal_penetration = a_face_query.0.max(b_face_query.0).max(edge_query.0);

    // if a_face_query.0 == minimal_penetration {
    // Transport `b` out of `a`

    // let mut reference_normal = (reference_face[1] - reference_face[0])
    //     .cross(reference_face[2] - reference_face[0])
    //     .normalize();

    let ref_plane = frames.0 * polytopes.0.plane(a_face_query.1);

    // debug.line_loop(ref_face, [0.0, 1.0, 0.0]);
    debug.plane(ref_plane, [0.0, 1.0, 1.0]);

    // if reference_normal.dot(reference_face[0] - pol)

    // Find incident face:
    let mut incident_plane = Plane::default();
    {
        let mut least_dot = f64::MAX;

        for plane in polytopes.1.planes() {
            let plane = frames.1 * plane;
            let dot = plane.normal.dot(ref_plane.normal);
            if dot < least_dot {
                incident_plane = plane;
                least_dot = dot;
            }
        }

        debug.plane(incident_plane, [1.0, 0.0, 1.0]);
    }
    // } else if b_face_query.0 == minimal_penetration {
    //     // Move `a` out of `b`
    // } else {
    //     // Move both edges
    //     let edges = edge_query.1;

    //     {
    //         let edge = polytopes.0.edges[edges.0];
    //         debug.line(
    //             [
    //                 frames.0.act(polytopes.0.vertices[edge.0]),
    //                 frames.0.act(polytopes.0.vertices[edge.1]),
    //             ],
    //             [0.0, 1.0, 0.0],
    //         )
    //     }

    //     {
    //         let edge = polytopes.1.edges[edges.1];
    //         debug.line(
    //             [
    //                 frames.1.act(polytopes.1.vertices[edge.0]),
    //                 frames.1.act(polytopes.1.vertices[edge.1]),
    //             ],
    //             [0.0, 1.0, 0.0],
    //         )
    //     }

    //     // edge_contact(frames, edge_query);
    // }

    false
}

pub fn face_axes_separation(
    frames: (Frame, Frame),
    polytopes: (&Polytope, &Polytope),
) -> (f64, usize) {
    let mut max_distance = f64::MIN;
    let mut face_index = usize::MAX;

    for (i, plane) in polytopes.0.planes().enumerate() {
        let support = polytopes
            .1
            .vertices
            .iter()
            .copied()
            .map(|p| frames.1 * p)
            .map(|p| frames.0.inverse() * p)
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
    frames: (Frame, Frame),
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
        let foot = frames.0 * polytopes.0.vertices[i.0];

        let edges = (
            frames.0 * polytopes.0.vertices[i.1] - foot,
            frames.1 * polytopes.1.vertices[j.1] - frames.1 * polytopes.1.vertices[j.0],
        );

        let mut axis = edges.0.cross(edges.1).normalize();

        // Keep normal pointing from `a` to `b`.
        if axis.dot(foot - frames.0 * polytopes.0.centroid) < 0.0 {
            axis = -axis;
        }

        // Ignore if another point on `a` is further in the direction to `b`.
        if polytopes.0.support(frames.0, axis).dot(axis) > foot.dot(axis) {
            continue;
        }

        let plane = Plane::from_point_normal(foot, axis);

        let distance = plane.distance(polytopes.1.support(frames.1, -axis));

        if distance > max_distance {
            max_distance = distance;
            edge_indices = (i_edge, j_edge);
        }
    }

    (max_distance, edge_indices)
}
