use std::cell::RefCell;

use crate::{collision::collide, constraint::Constraint, rigid::Rigid};

const SUBSTEP_COUNT: usize = 10;

fn solve(constraints: Vec<Constraint>, dt: f32) {
    let compliance = 1e-6 / (dt * dt); // TODO: What is the unit of `compliance`?

    for mut constraint in constraints {
        let difference = constraint.current_distance() - constraint.distance;
        let lagrange_factor = difference / (constraint.inverse_resistance() + compliance);
        constraint.act(lagrange_factor)
    }
}

fn integrate(rigid: &RefCell<Rigid>, dt: f32) {
    let dt = dt / SUBSTEP_COUNT as f32;

    for _ in 0..SUBSTEP_COUNT {
        rigid.borrow_mut().integrate(dt);

        let constraints = collide(rigid);
        solve(constraints, dt);

        rigid.borrow_mut().derive(dt);
    }
}
