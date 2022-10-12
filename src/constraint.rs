use std::{cell::RefCell, ops::Mul};

use cgmath::{ElementWise, InnerSpace, Vector3};

use crate::rigid::Rigid;

#[derive(Debug)]
pub struct Constraint<'a> {
    pub rigid: &'a RefCell<&'a mut Rigid>,
    pub contacts: (Vector3<f64>, Vector3<f64>),
    pub distance: f64,
}

impl Constraint<'_> {
    fn difference(&self) -> Vector3<f64> {
        self.contacts.1 - self.contacts.0
    }

    fn direction(&self) -> Vector3<f64> {
        self.difference().normalize()
    }

    pub fn current_distance(&self) -> f64 {
        self.difference().magnitude()
    }

    pub fn inverse_resitance(&self) -> f64 {
        let rigid = self.rigid.borrow();

        let angular_impulse = rigid.frame.quaternion.conjugate()
            * (self.contacts.0 - rigid.frame.position).cross(self.direction());

        rigid.inverse_mass + (rigid.inverse_inertia * angular_impulse).dot(angular_impulse)
    }

    pub fn act(&mut self, factor: f64) {
        let impulse = factor * self.direction();
        let mut rigid = self.rigid.borrow_mut();
        rigid.apply_impulse(impulse, self.contacts.0);
    }
}
