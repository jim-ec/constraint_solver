use cgmath::Matrix4;
use derive_setters::Setters;
use geometric_algebra::{
    pga3::{Motor, Point, Rotor, Translator},
    One, Transformation,
};

#[derive(Debug, Setters, Clone, Copy)]
pub struct Spatial {
    pub translator: Translator,
    pub rotor: Rotor,
    pub scale: f32,
}

impl Default for Spatial {
    fn default() -> Self {
        Self::identity()
    }
}

// TODO: Maybe rename to `Motion`?
impl Spatial {
    pub fn identity() -> Self {
        Self {
            translator: Translator::one(),
            rotor: Rotor::one(),
            scale: 1.0,
        }
    }

    pub fn motor(&self) -> Motor {
        self.translator * self.rotor
    }

    pub fn matrix(&self) -> Matrix4<f32> {
        let m = self.motor();
        let s = self.scale;
        [
            m.transformation(Point::new(s, 0.0, 0.0, 0.0)).g0.into(),
            m.transformation(Point::new(0.0, s, 0.0, 0.0)).g0.into(),
            m.transformation(Point::new(0.0, 0.0, s, 0.0)).g0.into(),
            m.transformation(Point::new(0.0, 0.0, 0.0, 1.0)).g0.into(),
        ]
        .into()
    }
}
