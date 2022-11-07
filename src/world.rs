use cgmath::{Deg, Euler, InnerSpace, Quaternion, Rotation3, Vector3, Zero};
use itertools::Itertools;
use std::ops::Add;

use crate::{collision, constraint::Constraint, debug, geometry, rigid, solver};

#[derive(Debug, Clone, Copy)]
pub struct World {
    pub a: rigid::Rigid,
    pub b: rigid::Rigid,
}

impl World {
    pub fn new(p1: &geometry::Polytope, p2: &geometry::Polytope) -> World {
        let a = rigid::Rigid::new(p1.rigid_metrics(0.1));
        let mut b = rigid::Rigid::new(p2.rigid_metrics(0.1));

        // b.position.x = 0.8;
        b.position.x = 0.4;
        b.position.y = 0.4;
        // b.position.z = 0.95;
        b.position.z = 2.0;
        // b.rotation = Euler::new(Deg(10.0), Deg(15.0), Deg(5.0)).into();

        b.external_force.z = -0.01;

        World { a, b }
    }

    #[allow(unused)]
    pub fn integrate(
        &mut self,
        dt: f64,
        p1: &geometry::Polytope,
        p2: &geometry::Polytope,
        debug: &mut debug::DebugLines,
    ) {
        // if collision::sat((self.a.frame(), self.b.frame()), (p1, p2), debug) {
        //     self.a.color = None;
        //     self.b.color = None;
        // } else {
        //     // self.a.color = Some([1.0, 0.0, 0.0]);
        //     // self.b.color = Some([1.0, 0.0, 0.0]);
        // }
        const SUBSTEPS: usize = 25;
        for _ in 0..SUBSTEPS {
            let dt = dt / SUBSTEPS as f64;

            let past_position = self.b.position;
            let past_rotation = self.b.rotation;
            let past_frame = self.b.frame();
            self.b.integrate(dt);

            match (
                collision::clip_step((self.a.frame(), self.b.frame()), (p1, p2)),
                collision::clip_step((self.b.frame(), self.a.frame()), (p2, p1)),
            ) {
                (Some(p), Some(q)) if !p.is_empty() && !q.is_empty() => {
                    println!("overlap");
                    // dbg!(&p, &q);

                    let pc = p.iter().fold(Vector3::zero(), Vector3::add) / p.len() as f64;
                    let qc = q.iter().fold(Vector3::zero(), Vector3::add) / q.len() as f64;
                    // // let c = p.iter().chain(q.iter()).fold(Vector3::zero(), Vector3::add)
                    // //     / (p.len() + q.len()) as f64;

                    // debug.point(pc, [1.0, 0.0, 0.0]);
                    // debug.point(qc, [0.0, 1.0, 0.0]);
                    // // debug.point(c, [1.0, 1.0, 0.0]);
                    // debug.line([pc, c], [1.0, 0.0, 0.0]);
                    // // debug.line([qc, c], [0.0, 1.0, 0.0]);
                    // debug.line_loop(p, [1.0, 0.0, 0.0]);
                    // debug.line_loop(q, [0.0, 1.0, 0.0]);

                    let c = Constraint {
                        rigid: 0,
                        contacts: (pc, qc),
                        distance: 0.0,
                    };

                    // dbg!(pc, qc);

                    // println!("solve...");
                    // dbg!(self.b.position, self.b.rotation);
                    solver::solve(&mut self.b, vec![c], dt);
                    // println!("solved");
                    // dbg!(self.b.position, self.b.rotation);
                }
                _ => (),
            }

            self.b.derive(past_position, past_rotation, dt);
        }

        // if let Some(poly) = collision::clip_step((self.a.frame(), self.b.frame()), (p1, p2)) {
        //     debug.line_loop(poly, [1.0, 0.0, 0.0]);
        // }

        // if let Some(poly) = collision::clip_step((self.b.frame(), self.a.frame()), (p2, p1)) {
        //     debug.line_loop(poly, [0.0, 1.0, 0.0]);
        // }

        // solver::step(&mut self.a, p1, dt, 25);

        // debug.point(self.a.position, [0.0, 0.0, 1.0]);
        // debug.point(self.a.position + self.a.center_of_mass, [1.0, 1.0, 0.0]);

        // solver::step(&mut self.b, p2, dt, 25);

        // debug.point(self.b.position, [0.0, 0.0, 1.0]);
        // debug.point(self.b.position + self.b.center_of_mass, [1.0, 1.0, 0.0]);
    }
}
