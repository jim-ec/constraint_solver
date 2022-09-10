use std::cell::RefCell;

use cgmath::{ElementWise, InnerSpace, Vector3};

use crate::rigid::Rigid;

#[derive(Debug)]
pub struct Constraint<'a> {
    pub rigid: &'a RefCell<Rigid>,
    pub contacts: (Vector3<f32>, Vector3<f32>),
    pub distance: f32,
}

impl Constraint<'_> {
    fn difference(&self) -> Vector3<f32> {
        self.contacts.1 - self.contacts.0
    }

    fn direction(&self) -> Vector3<f32> {
        self.difference().normalize()
    }

    pub fn current_distance(&self) -> f32 {
        self.difference().magnitude()
    }

    pub fn inverse_resistance(&self) -> f32 {
        let rigid = self.rigid.borrow();

        let angular_impulse = rigid.frame.quaternion.conjugate()
            * (self.contacts.0 - rigid.frame.position).cross(self.direction());

        rigid.inverse_mass
            + (rigid.inverse_inertia.mul_element_wise(angular_impulse)).dot(angular_impulse)
    }

    pub fn act(&mut self, factor: f32) {
        let impulse = factor * self.direction();
        let mut rigid = self.rigid.borrow_mut();
        rigid.apply_impulse(impulse, self.contacts.0);
    }
}
