use std::cell::RefCell;

use crate::{collision::ground, constraint::Constraint, rigid::Rigid};

pub fn step(rigid: &mut Rigid, dt: f64, substep_count: usize) {
    let rigid = RefCell::new(rigid);
    let dt = dt / substep_count as f64;

    for _ in 0..substep_count {
        rigid.borrow_mut().integrate(dt);

        let constraints = ground(&rigid);
        solve(constraints, dt);

        rigid.borrow_mut().derive(dt);
    }
}

pub fn solve(constraints: Vec<Constraint>, dt: f64) {
    let compliance = 1e-6 / (dt * dt);

    for mut constraint in constraints {
        let difference = constraint.current_distance() - constraint.distance;
        let lagrange_factor = difference / (constraint.resistance().recip() + compliance);
        constraint.act(lagrange_factor)
    }
}
