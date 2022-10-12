use std::cell::RefCell;

use crate::{collision::ground, constraint::Constraint, geometry::Polytope, rigid::Rigid};

pub fn step(rigid: &mut Rigid, polytope: &Polytope, dt: f64, substep_count: usize) {
    let rigid = RefCell::new(rigid);
    let dt = dt / substep_count as f64;

    for _ in 0..substep_count {
        let past = rigid.borrow().frame;
        rigid.borrow_mut().integrate(dt);

        let constraints = ground(&rigid, past, polytope);
        solve(constraints, dt);

        rigid.borrow_mut().derive(past, dt);
    }
}

pub fn solve(constraints: Vec<Constraint>, dt: f64) {
    let compliance = 1e-6 / (dt * dt);

    for mut constraint in constraints {
        let difference = constraint.current_distance() - constraint.distance;
        let lagrange_factor = difference / (constraint.inverse_resitance() + compliance);
        constraint.act(lagrange_factor)
    }
}
