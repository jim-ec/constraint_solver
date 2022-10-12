use std::{cell::RefCell, ops::Mul};

use cgmath::{ElementWise, InnerSpace, Vector3};

use crate::rigid::Rigid;

#[derive(Debug)]
pub struct Constraint {
    pub rigid: usize,
    pub contacts: (Vector3<f64>, Vector3<f64>),
    pub distance: f64,
}

impl Constraint {
    fn difference(&self) -> Vector3<f64> {
        self.contacts.1 - self.contacts.0
    }

    fn direction(&self) -> Vector3<f64> {
        self.difference().normalize()
    }

    pub fn current_distance(&self) -> f64 {
        self.difference().magnitude()
    }

    pub fn inverse_resitance(&self, rigids: &[&Rigid]) -> f64 {
        let rigid = &rigids[self.rigid];

        let angular_impulse = rigid.frame.rotation.conjugate()
            * (self.contacts.0 - rigid.frame.act(rigid.center_of_mass)).cross(self.direction());

        rigid.inverse_mass + (rigid.inverse_inertia * angular_impulse).dot(angular_impulse)
    }

    pub fn act(&mut self, rigids: &mut [&mut Rigid], factor: f64) {
        let impulse = factor * self.direction();
        rigids[self.rigid].apply_impulse(impulse, self.contacts.0);
    }
}
