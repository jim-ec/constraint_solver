use cgmath::{InnerSpace, Matrix4, Quaternion, Vector3, Zero};

#[derive(Debug, Clone, Copy)]
pub struct Frame {
    pub position: Vector3<f64>,
    pub rotation: Quaternion<f64>,
}

impl Default for Frame {
    fn default() -> Self {
        Frame {
            position: Vector3::zero(),
            rotation: Quaternion::new(1.0, 0.0, 0.0, 0.0),
        }
    }
}

impl Frame {
    pub fn matrix(&self) -> Matrix4<f32> {
        let mut m: Matrix4<f64> = self.rotation.into();
        m.w.x = self.position.x;
        m.w.y = self.position.y;
        m.w.z = self.position.z;
        m.cast().unwrap()
    }

    pub fn inverse(&self) -> Frame {
        let inverse_orientation = self.rotation.conjugate();
        let inverse_position = inverse_orientation * -self.position;
        Frame {
            position: inverse_position,
            rotation: inverse_orientation,
        }
    }

    pub fn act(&self, x: Vector3<f64>) -> Vector3<f64> {
        self.rotation * x + self.position
    }

    // The resulting frame first applies `other` and then `self`.
    #[allow(dead_code)]
    pub fn compose(&self, other: &Frame) -> Frame {
        Frame {
            position: self.position + self.rotation * other.position,
            rotation: self.rotation * other.rotation,
        }
    }

    pub fn integrate(
        &self,
        dt: f64,
        linear_velocity: Vector3<f64>,
        angular_velocity: Vector3<f64>,
    ) -> Frame {
        let position = self.position + dt * linear_velocity;

        let delta_rotation = dt
            * 0.5
            * Quaternion::new(
                0.0,
                angular_velocity.x,
                angular_velocity.y,
                angular_velocity.z,
            )
            * self.rotation;
        let rotation = (self.rotation + delta_rotation).normalize();

        Frame { position, rotation }
    }

    pub fn derive(&self, dt: f64, past: Frame) -> (Vector3<f64>, Vector3<f64>) {
        let derived_position = (self.position - past.position) / dt;

        let derived_rotation = {
            let delta = self.rotation * past.rotation.conjugate() / dt;
            let mut velocity = 2.0 * delta.v;
            if delta.s < 0.0 {
                velocity = -velocity;
            }
            velocity
        };

        (derived_position, derived_rotation)
    }
}
