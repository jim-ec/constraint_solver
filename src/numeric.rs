use cgmath::Quaternion;
use geometric_algebra::pga3::{Dir, Rotor, Scalar};

use rand::random;

pub fn random_dir() -> Dir {
    Scalar::new(2.0) * Dir::new(random::<f32>(), random::<f32>(), random::<f32>())
        - Dir::new(1.0, 1.0, 1.0)
}

pub fn pertube(d: Dir, scale: f32) -> Dir {
    d + Scalar { g0: scale } * random_dir()
}

pub fn quat_to_rotor(q: Quaternion<f32>) -> Rotor {
    Rotor::new(-q.v.x, -q.v.y, -q.v.z, q.s)
}

pub fn rotor_to_quat(r: Rotor) -> Quaternion<f32> {
    Quaternion::new(r.g0[3], -r.g0[0], -r.g0[1], -r.g0[2])
}
