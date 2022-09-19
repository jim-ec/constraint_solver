use cgmath::{InnerSpace, Quaternion, Vector3, Zero};
use geometric_algebra::{
    pga3::{Rotor, Scalar},
    Inverse, Magnitude, One, Reversal, ScalarPart, Signum,
};

use crate::numeric::{quat_to_rotor, rotor_to_quat};

#[derive(Debug, Clone, Copy)]
pub struct Frame {
    pub position: Vector3<f32>,
    pub rotor: Rotor,
}

impl Frame {
    pub fn identity() -> Frame {
        Frame {
            position: Vector3::zero(),
            rotor: Rotor::one(),
        }
    }

    pub fn inverse(&self) -> Frame {
        let inverse_orientation = self.rotor.inverse();
        let inverse_position = rotor_to_quat(inverse_orientation) * -self.position;
        Frame {
            position: inverse_position,
            rotor: inverse_orientation,
        }
    }

    pub fn act(&self, x: Vector3<f32>) -> Vector3<f32> {
        rotor_to_quat(self.rotor.signum()) * x + self.position
    }

    pub fn integrate(
        &self,
        dt: f32,
        linear_velocity: Vector3<f32>,
        angular_velocity: Vector3<f32>,
    ) -> Frame {
        let position = self.position + dt * linear_velocity;

        let delta_rotor = Scalar::new(0.5 * dt)
            * -Rotor::new(
                angular_velocity.x,
                angular_velocity.y,
                angular_velocity.z,
                0.0,
            )
            * self.rotor;

        let rotor = (self.rotor + delta_rotor).signum();

        Frame { position, rotor }
    }

    pub fn derive(&self, dt: f32, past: Frame) -> (Vector3<f32>, Vector3<f32>) {
        let derived_position = (self.position - past.position) / dt;

        let derived_rotation = {
            let delta = Scalar::new(-2.0 / dt) * self.rotor * past.rotor.inverse();
            let delta = -delta.constrain();
            Vector3::new(delta.g0[1], delta.g0[2], delta.g0[3])
        };

        (derived_position, derived_rotation)
    }
}
