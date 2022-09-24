use std::f32::consts::TAU;

use cgmath::{Matrix4, Quaternion, Rotation3, Vector3, Vector4};

#[derive(Debug, Clone, Copy)]
pub struct Camera {
    pub orbit: f32,
    pub tilt: f32,
    pub distance: f32,
    pub fovy: f32,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct CameraUniforms {
    pub view: Matrix4<f32>,
    pub proj: Matrix4<f32>,
}

unsafe impl bytemuck::Pod for CameraUniforms {}
unsafe impl bytemuck::Zeroable for CameraUniforms {}

/// Converts from a Z-up right-handed coordinate system into a Y-up left-handed coordinate system.
const Y_UP: Matrix4<f32> = Matrix4::from_cols(
    Vector4::new(0.0, 0.0, 1.0, 0.0),
    Vector4::new(1.0, 0.0, 0.0, 0.0),
    Vector4::new(0.0, 1.0, 0.0, 0.0),
    Vector4::new(0.0, 0.0, 0.0, 1.0),
);

impl Camera {
    pub fn initial() -> Self {
        Self {
            orbit: -0.1 * TAU,
            tilt: 0.3 * 0.25 * TAU,
            distance: 12.0,
            fovy: 60.0,
        }
    }

    pub fn clamp_tilt(&mut self) {
        self.tilt = self.tilt.clamp(-TAU / 4.0, TAU / 4.0);
    }

    pub fn uniforms(&self, aspect: f32) -> CameraUniforms {
        let orbit = Quaternion::from_angle_z(cgmath::Rad(self.orbit as f32));
        let tilt = Quaternion::from_angle_y(cgmath::Rad(self.tilt as f32));
        let translation =
            Matrix4::from_translation(Vector3::new(-1.0 * self.distance as f32, 0.0, 0.0));

        let view = translation * Matrix4::from(tilt * orbit);

        let proj = perspective_matrix(f32::to_radians(60.0), aspect, 0.01, None) * Y_UP;

        CameraUniforms { view, proj }
    }
}

fn perspective_matrix(fovy: f32, aspect: f32, near: f32, far: Option<f32>) -> Matrix4<f32> {
    let tan_half_fovy = (0.5 * fovy).tan();
    if let Some(far) = far {
        Matrix4::from_cols(
            Vector4::new(1.0 / (aspect * tan_half_fovy), 0.0, 0.0, 0.0),
            Vector4::new(0.0, 1.0 / tan_half_fovy, 0.0, 0.0),
            Vector4::new(0.0, 0.0, -(far + near) / (far - near), -1.0),
            Vector4::new(0.0, 0.0, -2.0 * far * near / (far - near), 0.0),
        )
    } else {
        Matrix4::from_cols(
            Vector4::new(1.0 / (aspect * tan_half_fovy), 0.0, 0.0, 0.0),
            Vector4::new(0.0, 1.0 / tan_half_fovy, 0.0, 0.0),
            Vector4::new(0.0, 0.0, -1.0, -1.0),
            Vector4::new(0.0, 0.0, -2.0 * near, 0.0),
        )
    }
}
