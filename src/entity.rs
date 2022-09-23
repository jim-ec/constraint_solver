use derive_setters::Setters;

use crate::{frame::Frame, mesh::Mesh};

#[derive(Debug, Clone, Setters)]
pub struct Entity<'a> {
    pub frame: Frame,
    pub mesh: &'a Mesh,
}
