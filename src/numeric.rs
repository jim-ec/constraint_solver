use cgmath::{Matrix4, Quaternion};
use geometric_algebra::{
    pga3::{Motor, Point, Rotor},
    Transformation,
};

pub fn quat_to_rotor(q: Quaternion<f32>) -> Rotor {
    Rotor::new(-q.v.x, -q.v.y, -q.v.z, q.s)
}

pub fn motor_to_matrix(m: Motor) -> Matrix4<f32> {
    [
        m.transformation(Point::new(1.0, 0.0, 0.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 1.0, 0.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 0.0, 1.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 0.0, 0.0, 1.0)).g0.into(),
    ]
    .into()
}
