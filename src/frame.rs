use cgmath::{Matrix4, Quaternion, Vector3, Zero};
use derive_setters::Setters;

#[derive(Debug, Clone, Copy, Setters)]
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

    /// Computes the position difference of a global point in the current frame from the same point in the past frame.
    pub fn delta(&self, past: Frame, global: Vector3<f64>) -> Vector3<f64> {
        let local = self.inverse().act(global);
        let past_global = past.act(local);
        global - past_global
    }
}
