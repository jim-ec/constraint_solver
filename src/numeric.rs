use geometric_algebra::pga3::{Dir, Scalar};

use rand::random;

pub fn random_dir() -> Dir {
    Scalar::new(2.0) * Dir::new(random::<f32>(), random::<f32>(), random::<f32>())
        - Dir::new(1.0, 1.0, 1.0)
}

pub fn pertube(d: Dir, scale: f32) -> Dir {
    d + Scalar { g0: scale } * random_dir()
}
