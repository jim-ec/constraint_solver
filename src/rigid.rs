use cgmath::{ElementWise, InnerSpace, Quaternion, Vector3, Zero};

use crate::frame::Frame;

#[derive(Debug, Clone, Copy)]
pub struct Rigid {
    /// Mass in `kg`
    pub mass: f32,

    /// Rotational inertia in `kg m^2`
    pub rotational_inertia: Vector3<f32>,

    /// Force acting on the rigid body in `N`
    pub force: Vector3<f32>,

    /// Current velocity of the rigid body in `m s^-1`
    pub velocity: Vector3<f32>,

    /// Current angular velocity of the rigid body in `s^-1`
    pub angular_velocity: Vector3<f32>,

    pub frame: Frame,
    pub past_frame: Frame,
}

impl Rigid {
    pub fn new(mass: f32) -> Rigid {
        let extent = Vector3::new(1.0, 1.0, 1.0);
        let inertia = 1.0 / 12.0
            * mass
            * Vector3::new(
                extent.y * extent.y + extent.z * extent.z,
                extent.x * extent.x + extent.z * extent.z,
                extent.x * extent.x + extent.y * extent.y,
            );

        Rigid {
            mass,
            rotational_inertia: inertia,
            force: Vector3::zero(),
            velocity: Vector3::zero(),
            angular_velocity: Vector3::zero(),
            frame: Frame::identity(),
            past_frame: Frame::identity(),
        }
    }

    pub fn integrate(&mut self, dt: f32) {
        // TODO: Consider torque
        self.velocity += dt * self.force / self.mass;
        self.past_frame = self.frame;
        self.frame = self
            .frame
            .integrate(dt, self.velocity, self.angular_velocity);
    }

    pub fn derive(&mut self, dt: f32) {
        (self.velocity, self.angular_velocity) = self.frame.derive(dt, self.past_frame)
    }

    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and quaternion.
    pub fn apply_impulse(&mut self, impulse: Vector3<f32>, point: Vector3<f32>) {
        self.frame.position += impulse / self.mass;

        let log = (point - self.frame.position)
            .div_element_wise(self.rotational_inertia)
            .cross(impulse);
        let rotation = 0.5 * Quaternion::new(0.0, log.x, log.y, log.z) * self.frame.quaternion;
        self.frame.quaternion = (self.frame.quaternion + rotation).normalize();
    }

    /// Computes the position difference of a global point in the current frame from the same point in the past frame.
    pub fn delta(&self, global: Vector3<f32>) -> Vector3<f32> {
        let local = self.frame.inverse().act(global);
        let past_global = self.past_frame.act(local);
        global - past_global
    }
}
