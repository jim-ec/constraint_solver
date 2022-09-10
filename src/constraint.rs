use std::cell::RefCell;

use cgmath::{ElementWise, InnerSpace, Vector3};

use crate::rigid::Rigid;

pub trait Constraint {
    fn measure(&self) -> f32;
    fn target_measure(&self) -> f32;
    fn inverse_resistance(&self) -> f32;
    fn act(&mut self, factor: f32);
}

#[derive(Debug)]
pub struct PositionalConstraint<'a> {
    pub rigid: &'a RefCell<Rigid>,
    pub contacts: (Vector3<f32>, Vector3<f32>),
    pub distance: f32,
}

impl PositionalConstraint<'_> {
    fn difference(&self) -> Vector3<f32> {
        self.contacts.1 - self.contacts.0
    }

    fn direction(&self) -> Vector3<f32> {
        self.difference().normalize()
    }
}

impl Constraint for PositionalConstraint<'_> {
    fn measure(&self) -> f32 {
        self.difference().magnitude()
    }

    fn target_measure(&self) -> f32 {
        self.distance
    }

    fn inverse_resistance(&self) -> f32 {
        let rigid = self.rigid.borrow();

        let angular_impulse_dual = rigid.frame.quaternion.conjugate()
            * (self.contacts.0 - rigid.frame.position).cross(self.direction());

        rigid.inverse_mass
            + (rigid.inverse_inertia.mul_element_wise(angular_impulse_dual))
                .dot(angular_impulse_dual)
    }

    fn act(&mut self, factor: f32) {
        let impulse = factor * self.direction();
        let mut rigid = self.rigid.borrow_mut();
        rigid.apply_impulse(impulse, self.contacts.0);
    }
}
