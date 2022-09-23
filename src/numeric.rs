#![allow(dead_code)]

use cgmath::{Matrix4, Quaternion, Vector3, Vector4};
use geometric_algebra::{
    pga3::{IdealLine, Motor, Point, Rotor, Translator},
    Exp, Ln, Magnitude, Transformation,
};

pub fn quat_to_rotor(q: Quaternion<f32>) -> Rotor {
    Rotor::new(-q.v.x, -q.v.y, -q.v.z, q.s)
}

pub fn rotor_to_quat(r: Rotor) -> Quaternion<f32> {
    Quaternion::new(r.g0[0], -r.g0[1], -r.g0[2], -r.g0[3])
}

pub fn vector_to_point(v: Vector3<f32>) -> Point {
    Point::at(v.x, v.y, v.z)
}

pub fn point_to_vector(v: Point) -> Vector3<f32> {
    let w = v.magnitude().g0;
    Vector3::new(v.g0[0] / w, v.g0[1] / w, v.g0[2] / w)
}

pub fn vector_to_idealline(v: Vector3<f32>) -> IdealLine {
    IdealLine {
        g0: [v.x / -2.0, v.y / -2.0, v.z / -2.0].into(),
    }
}

pub fn idealline_to_vector(v: IdealLine) -> Vector3<f32> {
    Vector3::new(v.g0[0] * -2.0, v.g0[1] * -2.0, v.g0[2] * -2.0)
}

pub fn translator_to_vector(v: Translator) -> Vector3<f32> {
    idealline_to_vector(v.ln())
}

pub fn vector_to_translator(v: Vector3<f32>) -> Translator {
    vector_to_idealline(v).exp()
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
