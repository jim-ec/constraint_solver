use cgmath::Vector3;
use geometric_algebra::{
    pga3::{Rotor, Scalar, Translator},
    Exp, Inverse, Ln, One, Powf, ScalarPart, Signum, Transformation,
};

use crate::numeric::{rotor_to_quat, translator_to_vector, vector_to_translator};

#[derive(Debug, Clone, Copy)]
pub struct Frame {
    pub translator: Translator,
    pub rotor: Rotor,
}

impl Frame {
    pub fn identity() -> Frame {
        Frame {
            translator: Translator::one(),
            rotor: Rotor::one(),
        }
    }

    pub fn position(&self) -> Vector3<f32> {
        translator_to_vector(self.translator)
    }

    pub fn inverse(&self) -> Frame {
        let inverse_orientation = self.rotor.inverse();
        let inverse_translator = inverse_orientation.transformation(self.translator.inverse());
        Frame {
            translator: inverse_translator,
            rotor: inverse_orientation,
        }
    }

    pub fn act(&self, x: Vector3<f32>) -> Vector3<f32> {
        rotor_to_quat(self.rotor.signum()) * x + self.position()
    }

    pub fn integrate(
        &self,
        dt: f32,
        linear_velocity: Vector3<f32>,
        angular_velocity: Vector3<f32>,
    ) -> Frame {
        let translator = self.translator * vector_to_translator(linear_velocity).powf(dt);

        let delta_rotor = Scalar::new(0.5 * dt)
            * -Rotor::new(
                angular_velocity.x,
                angular_velocity.y,
                angular_velocity.z,
                0.0,
            )
            * self.rotor;

        let rotor = (self.rotor + delta_rotor).signum();

        Frame { translator, rotor }
    }

    pub fn derive(&self, dt: f32, past: Frame) -> (Vector3<f32>, Vector3<f32>) {
        let translator_derivative = (self.translator.ln() - past.translator.ln())
            .exp()
            .powf(1.0 / dt);

        let derived_rotation = {
            let mut delta = Scalar::new(-2.0 / dt) * self.rotor * past.rotor.inverse();
            delta = -delta.constrain();
            Vector3::new(delta.g0[1], delta.g0[2], delta.g0[3])
        };

        (
            translator_to_vector(translator_derivative),
            derived_rotation,
        )
    }
}
