use std::cell::RefCell;

use cgmath::{InnerSpace, Vector3};

use crate::{constraint::Constraint, rigid::Rigid};

const CUBE_VERTICES: [Vector3<f64>; 8] = [
    Vector3::new(-0.5, -0.5, -0.5),
    Vector3::new(0.5, -0.5, -0.5),
    Vector3::new(-0.5, 0.5, -0.5),
    Vector3::new(0.5, 0.5, -0.5),
    Vector3::new(-0.5, -0.5, 0.5),
    Vector3::new(0.5, -0.5, 0.5),
    Vector3::new(-0.5, 0.5, 0.5),
    Vector3::new(0.5, 0.5, 0.5),
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

#[allow(dead_code)]
fn support(dir: Vector3<f64>) -> Vector3<f64> {
    CUBE_VERTICES
        .into_iter()
        .max_by(|a, b| a.dot(dir).total_cmp(&b.dot(dir)))
        .unwrap()
}
