use cgmath::{InnerSpace, Vector3, Zero};
use itertools::Itertools;

use crate::{
    debug,
    geometry::{Plane, Polytope},
    rigid::Rigid,
};

#[allow(dead_code)]
pub fn brute_force_axis_separation(
    rigids: (&Rigid, &Rigid),
    polytope: &Polytope,
    axis: Vector3<f64>,
) -> f64 {
    let mut self_max = f64::MIN;
    let mut other_min = f64::MAX;

    // Compute the shadow self's vertices cast onto the axis.
    for &vertex in &polytope.vertices {
        let vertex = rigids.0.frame().act(vertex);
        let projection = vertex.dot(axis);
        self_max = self_max.max(projection);
    }

    // Compute the shadow other's vertices cast onto the axis.
    for &vertex in &polytope.vertices {
        let vertex = rigids.1.frame().act(vertex);
        let projection = vertex.dot(axis);
        other_min = other_min.min(projection);
    }

    other_min - self_max
}

pub fn face_axes_separation(rigids: (&Rigid, &Rigid), polytope: &Polytope) -> (f64, usize) {
    let mut max_distance = f64::MIN;
    let mut face_index = usize::MAX;

    for (i, plane) in polytope.planes() {
        let support = polytope
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
    polytope: &Polytope,
    debug: &mut debug::DebugLines,
) -> (f64, (usize, usize)) {
    let mut max_distance = f64::MIN;
    let mut edge_indices = (usize::MAX, usize::MAX);

    for ((i_edge, i), (j_edge, j)) in polytope
        .edges
        .iter()
        .copied()
        .enumerate()
        .cartesian_product(polytope.edges.iter().copied().enumerate())
    {
        let foot = rigids.0.frame().act(polytope.vertices[i.0]);

        let edges = (
            rigids.0.frame().act(polytope.vertices[i.1]) - foot,
            rigids.1.frame().act(polytope.vertices[j.1])
                - rigids.1.frame().act(polytope.vertices[j.0]),
        );

        let mut axis = edges.0.cross(edges.1).normalize();

        // Keep normal pointing from `self` to `other`.
        if axis.dot(foot - rigids.0.frame().act(Vector3::zero())) < 0.0 {
            axis = -axis;
        }

        let plane = Plane::from_point_normal(polytope.support(&rigids.0.frame(), axis), axis);
        let distance = plane.distance(polytope.support(&rigids.1.frame(), -axis));

        if distance > max_distance {
            max_distance = distance;
            edge_indices = (i_edge, j_edge);
        }
    }

    (max_distance, edge_indices)
}

pub fn face_contact(rigids: (&Rigid, &Rigid), queries: ((f64, usize), (f64, usize))) {}

pub fn edge_contact(rigids: (&Rigid, &Rigid), query: (f64, (usize, usize))) {}
