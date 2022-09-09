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
    pub rigids: (&'a mut Rigid, &'a mut Rigid),
    pub contacts: (Vector3<f32>, Vector3<f32>),
    pub distance: f32,
}

impl<'a> PositionalConstraint<'a> {
    fn difference(&self) -> Vector3<f32> {
        self.contacts.1 - self.contacts.0
    }

    fn direction(&self) -> Vector3<f32> {
        self.difference().normalize()
    }
}

impl<'a> Constraint for PositionalConstraint<'a> {
    fn measure(&self) -> f32 {
        self.difference().magnitude()
    }

    fn target_measure(&self) -> f32 {
        self.distance
    }

    fn inverse_resistance(&self) -> f32 {
        let angular_impulse_dual = (
            self.rigids.0.frame.quaternion.conjugate()
                * (self.contacts.0 - self.rigids.0.frame.position).cross(self.direction()),
            self.rigids.1.frame.quaternion
                * (self.contacts.1 - self.rigids.1.frame.position).cross(self.direction()),
        );

        self.rigids.0.inverse_mass
            + self.rigids.1.inverse_mass
            + (self
                .rigids
                .0
                .inverse_inertia
                .mul_element_wise(angular_impulse_dual.0))
            .dot(angular_impulse_dual.0)
            + (self
                .rigids
                .1
                .inverse_inertia
                .mul_element_wise(angular_impulse_dual.1))
            .dot(angular_impulse_dual.1)
    }

    fn act(&mut self, factor: f32) {
        let impulse = factor * self.direction();
        self.rigids.0.apply_impulse(impulse, self.contacts.0);
        self.rigids.1.apply_impulse(-impulse, self.contacts.1);
    }
}
