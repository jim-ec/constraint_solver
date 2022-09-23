use std::rc::Rc;

use derive_setters::Setters;

use crate::{frame::Frame, mesh::Mesh};

#[derive(Debug, Clone, Setters, Default)]
pub struct Entity {
    pub frame: Frame,
    pub meshes: Vec<Rc<Mesh>>,
}
