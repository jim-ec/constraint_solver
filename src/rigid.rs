use cgmath::{InnerSpace, Matrix3, Quaternion, SquareMatrix, Vector3, Zero};
use derive_setters::Setters;

use crate::{frame::Frame, geometry::integrate::RigidMetrics};

#[derive(Debug, Clone, Copy, Setters)]
pub struct Rigid {
    /// Mass in `kg`
    pub inverse_mass: f64,

    /// Inverse rotational inertia tensor.
    /// Since the geometry is assumed to be in rest space,
    /// this tensor is sparse and just the diagonal entries are stored.
    /// Measured in `kg^-1 m^-2`.
    pub inverse_inertia: Matrix3<f64>,

    /// Force acting on the rigid body outside its frame.
    /// Measured in `N`.
    pub external_force: Vector3<f64>,

    /// Force acting on the rigid body within its own frame.
    /// Measured in `N`.
    pub internal_force: Vector3<f64>,

    /// Torque acting on the rigid body outside its frame.
    /// Measrued in `N m`.
    pub external_torque: Vector3<f64>,

    /// Torque acting on the rigid body within its own frame.
    /// Measrued in `N m`.
    pub internal_torque: Vector3<f64>,

    /// Current velocity of the rigid body in `m s^-1`
    pub velocity: Vector3<f64>,

    /// Current angular velocity of the rigid body in `s^-1`
    pub angular_velocity: Vector3<f64>,

    /// The center of mass in object space.
    pub center_of_mass: Vector3<f64>,

    /// The translation relative to the world origin.
    pub position: Vector3<f64>,

    /// The rotation around the center of mass, i.e. in rest space.
    /// One transforms from rest space to object space by translating the origin to the center of mass.
    pub rotation: Quaternion<f64>,

    pub color: Option<[f32; 3]>,
}

impl Rigid {
    pub fn new(metrics: RigidMetrics) -> Rigid {
        Rigid {
            inverse_mass: 1.0 / metrics.mass,
            inverse_inertia: metrics
                .inertia_tensor
                .invert()
                .expect("Inertia tensor is not invertible"),
            internal_force: Vector3::zero(),
            external_force: Vector3::zero(),
            internal_torque: Vector3::zero(),
            external_torque: Vector3::zero(),
            velocity: Vector3::zero(),
            angular_velocity: Vector3::zero(),
            center_of_mass: metrics.center_of_mass,
            position: Vector3::zero(),
            rotation: Quaternion::from_sv(1.0, Vector3::zero()),
            color: None,
        }
    }

    /// A frame which transforms from object space to world space.
    /// It incorporates both the world space translation and rest space rotation.
    pub fn frame(&self) -> Frame {
        Frame {
            position: self.position + self.center_of_mass + self.rotation * -self.center_of_mass,
            rotation: self.rotation,
        }
    }

    pub fn integrate(&mut self, dt: f64) {
        let force = self.external_force + self.rotation * self.internal_force;
        self.velocity += dt * force * self.inverse_mass;
        self.position += dt * self.velocity;

        let torque = self.external_torque + self.rotation * self.internal_torque;
        self.angular_velocity += dt * self.inverse_inertia * torque;
        let delta_rotation = dt
            * 0.5
            * Quaternion::new(
                0.0,
                self.angular_velocity.x,
                self.angular_velocity.y,
                self.angular_velocity.z,
            )
            * self.rotation;
        self.rotation = (self.rotation + delta_rotation).normalize();
    }

    pub fn derive(&mut self, position: Vector3<f64>, rotation: Quaternion<f64>, dt: f64) {
        self.velocity = (self.position - position) / dt;

        let mut delta = self.rotation * rotation.conjugate();
        if delta.s < 0.0 {
            delta = -delta;
        }
        self.angular_velocity = 2.0 * delta.v / dt;
    }

    /// Applies a linear impulse in a given direction and magnitude at a given
    /// Results in changes in both position and rotation.
    pub fn apply_impulse(&mut self, impulse: Vector3<f64>, point: Vector3<f64>) {
        self.position += impulse * self.inverse_mass;

        self.rotation +=
            0.5 * Quaternion::from_sv(
                0.0,
                (self.inverse_inertia * (point - (self.position + self.center_of_mass)))
                    .cross(impulse),
            ) * self.rotation;
        self.rotation = self.rotation.normalize();
    }
}
