use std::cell::RefCell;

use crate::{collision::collide, constraint::Constraint, rigid::Rigid};

pub fn solve(constraints: Vec<Constraint>, dt: f32) {
    let compliance = 1e-6 / (dt * dt); // TODO: What is the unit of `compliance`?

    for mut constraint in constraints {
        let difference = constraint.current_distance() - constraint.distance;
        let lagrange_factor = difference / (constraint.resistance().recip() + compliance);
        constraint.act(lagrange_factor)
    }
}

pub fn integrate(rigid: &RefCell<Rigid>, dt: f32, substep_count: usize) {
    let dt = dt / substep_count as f32;

    for _ in 0..substep_count {
        rigid.borrow_mut().integrate(dt);

        let constraints = collide(rigid);
        solve(constraints, dt);

        rigid.borrow_mut().derive(dt);
    }
}
