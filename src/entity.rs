use std::rc::Rc;

use derive_setters::Setters;

use crate::{mesh::Mesh, spatial::Spatial};

#[derive(Debug, Clone, Setters, Default)]
pub struct Entity {
    pub spatial: Spatial,
    pub meshes: Vec<Rc<Mesh>>,
}
