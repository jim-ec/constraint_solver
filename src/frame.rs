use cgmath::{Matrix4, Quaternion, Vector3, Zero};
use derive_setters::Setters;

use crate::geometry::Plane;

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

    /// Computes the position difference of a global point in the current frame from the same point in the past frame.
    pub fn delta(&self, past: Frame, global: Vector3<f64>) -> Vector3<f64> {
        let local = self.inverse() * global;
        let past_global = past * local;
        global - past_global
    }
}

impl std::ops::Mul<Vector3<f64>> for Frame {
    type Output = Vector3<f64>;

    fn mul(self, rhs: Vector3<f64>) -> Self::Output {
        self.rotation * rhs + self.position
    }
}

impl std::ops::Mul<Plane> for Frame {
    type Output = Plane;

    fn mul(self, rhs: Plane) -> Self::Output {
        let support = rhs.displacement * rhs.normal;
        let support = self * support;
        let normal = self.rotation * rhs.normal;
        Plane::from_point_normal(support, normal)
    }
}

/// The resulting frame first applies `other` and then `self`.
impl std::ops::Mul for Frame {
    type Output = Frame;

    fn mul(self, rhs: Frame) -> Self::Output {
        Frame {
            position: self.position + self.rotation * rhs.position,
            rotation: self.rotation * rhs.rotation,
        }
    }
}
