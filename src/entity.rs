use std::rc::Rc;

use derive_setters::Setters;

use crate::{mesh::Mesh, spatial::Spatial};

#[derive(Debug, Clone, Setters)]
pub struct Entity {
    pub spatial: Spatial,
    pub meshes: Vec<Rc<Mesh>>,
    pub sub_entities: Vec<Entity>,
}

impl Entity {
    pub fn new() -> Self {
        Self {
            spatial: Spatial::identity(),
            meshes: vec![],
            sub_entities: vec![],
        }
    }
}
