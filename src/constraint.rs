use std::cell::RefCell;

use cgmath::{ElementWise, InnerSpace, Vector3};

use crate::rigid::Rigid;

#[derive(Debug)]
pub struct Constraint<'a> {
    pub rigids: (&'a RefCell<Rigid>, &'a RefCell<Rigid>),
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

    pub fn resistance(&self) -> f32 {
        let rigids = (self.rigids.0.borrow(), self.rigids.1.borrow());

        let angular_impulse_0 = rigids.0.frame.quaternion.conjugate()
            * (self.contacts.0 - rigids.0.frame.position).cross(self.direction());

        let angular_impulse_1 = rigids.1.frame.quaternion.conjugate()
            * (self.contacts.1 - rigids.1.frame.position).cross(self.direction());

        let linear_resistance_0 = rigids.0.mass.recip();
        let linear_resistance_1 = rigids.1.mass.recip();

        let rotational_resistance_0 = (angular_impulse_0
            .div_element_wise(rigids.0.rotational_inertia))
        .dot(angular_impulse_0);

        let rotational_resistance_1 = (angular_impulse_1
            .div_element_wise(rigids.1.rotational_inertia))
        .dot(angular_impulse_1);

        linear_resistance_0
            + linear_resistance_1
            + rotational_resistance_0
            + rotational_resistance_1
    }

    pub fn act(&mut self, factor: f32) {
        let impulse = factor * self.direction();

        self.rigids
            .0
            .borrow_mut()
            .apply_impulse(impulse, self.contacts.0);

        self.rigids
            .1
            .borrow_mut()
            .apply_impulse(-impulse, self.contacts.1);
    }
}
