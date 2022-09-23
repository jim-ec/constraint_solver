use cgmath::{Matrix4, Vector4};
use geometric_algebra::{
    pga3::{Motor, Point},
    Transformation,
};

pub fn motor_to_matrix(m: Motor) -> Matrix4<f32> {
    [
        m.transformation(Point::new(1.0, 0.0, 0.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 1.0, 0.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 0.0, 1.0, 0.0)).g0.into(),
        m.transformation(Point::new(0.0, 0.0, 0.0, 1.0)).g0.into(),
    ]
    .into()
}

/// Converts from a Z-up right-handed coordinate system into a Y-up left-handed coordinate system.
#[allow(dead_code)]
pub const Y_UP: Matrix4<f32> = Matrix4::from_cols(
    Vector4::new(0.0, 0.0, 1.0, 0.0),
    Vector4::new(1.0, 0.0, 0.0, 0.0),
    Vector4::new(0.0, 1.0, 0.0, 0.0),
    Vector4::new(0.0, 0.0, 0.0, 1.0),
);

/// Converts from a Y-up left-handed coordinate system into a Z-up right-handed coordinate system.
#[allow(dead_code)]
pub const Z_UP: Matrix4<f32> = Matrix4::from_cols(
    Vector4::new(0.0, 1.0, 0.0, 0.0),
    Vector4::new(0.0, 0.0, 1.0, 0.0),
    Vector4::new(1.0, 0.0, 0.0, 0.0),
    Vector4::new(0.0, 0.0, 0.0, 1.0),
);

/// The identity matrix.
#[allow(dead_code)]
pub const IDENTITY: Matrix4<f32> = Matrix4::from_cols(
    Vector4::new(1.0, 0.0, 0.0, 0.0),
    Vector4::new(0.0, 1.0, 0.0, 0.0),
    Vector4::new(0.0, 0.0, 1.0, 0.0),
    Vector4::new(0.0, 0.0, 0.0, 1.0),
);
