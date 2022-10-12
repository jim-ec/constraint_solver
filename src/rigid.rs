use cgmath::{vec3, ElementWise, InnerSpace, Matrix3, Quaternion, SquareMatrix, Vector3, Zero};
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

    pub center_of_mass: Vector3<f64>,

    pub frame: Frame,

    pub color: Option<[f32; 3]>,
}

impl Rigid {
    pub fn new(metrics: RigidMetrics) -> Rigid {
        Rigid {
            inverse_mass: 1.0 / metrics.mass,
            center_of_mass: metrics.center_of_mass,
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
            frame: Frame::default(),
            color: None,
        }
    }

    pub fn integrate(&mut self, dt: f64) {
        let force = self.external_force + self.frame.rotation * self.internal_force;
        self.velocity += dt * force * self.inverse_mass;

        let torque = self.external_torque + self.frame.rotation * self.internal_torque;
        self.angular_velocity += dt * self.inverse_inertia * torque;

        self.frame = self
            .frame
            .integrate(dt, self.velocity, self.angular_velocity);
    }

    pub fn derive(&mut self, past: Frame, dt: f64) {
        (self.velocity, self.angular_velocity) = self.frame.derive(dt, past)
    }

    /// Applies a linear impulse in a given direction and magnitude at a given location.
    /// Results in changes in both position and rotation.
    pub fn apply_impulse(&mut self, impulse: Vector3<f64>, point: Vector3<f64>) {
        self.frame.position += impulse * self.inverse_mass;

        self.frame.rotation +=
            0.5 * Quaternion::from_sv(
                0.0,
                (self.inverse_inertia * (point - self.frame.position)).cross(impulse),
            ) * self.frame.rotation;
        self.frame.rotation = self.frame.rotation.normalize();
    }

    /// Computes the position difference of a global point in the current frame from the same point in the past frame.
    // TODO: Move to frame module
    pub fn delta(&self, past: Frame, global: Vector3<f64>) -> Vector3<f64> {
        let local = self.frame.inverse().act(global);
        let past_global = past.act(local);
        global - past_global
    }
}
