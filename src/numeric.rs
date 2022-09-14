use cgmath::Quaternion;
use geometric_algebra::pga3::Rotor;

pub fn quat_to_rotor(q: Quaternion<f32>) -> Rotor {
    Rotor::new(-q.v.x, -q.v.y, -q.v.z, q.s)
}
