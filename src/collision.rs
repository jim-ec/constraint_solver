use std::cell::RefCell;

use cgmath::{InnerSpace, Vector3};

use crate::{
    constraint::{Constraint, PositionalConstraint},
    rigid::Rigid,
};

fn collision(rigid: &RefCell<Rigid>) -> Vec<impl Constraint + '_> {
    let mut constraints = Vec::new();

    let vertices = [
        Vector3::new(-0.5, -0.5, -0.5),
        Vector3::new(0.5, -0.5, -0.5),
        Vector3::new(-0.5, 0.5, -0.5),
        Vector3::new(0.5, 0.5, -0.5),
        Vector3::new(-0.5, -0.5, 0.5),
        Vector3::new(0.5, -0.5, 0.5),
        Vector3::new(-0.5, 0.5, 0.5),
        Vector3::new(0.5, 0.5, 0.5),
    ];

    for position in vertices {
        let position = rigid.borrow().frame.act(position);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = rigid.borrow().delta(position);
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(PositionalConstraint {
            rigid,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}
