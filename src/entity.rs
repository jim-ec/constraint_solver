use std::rc::Rc;

use derive_setters::Setters;
use geometric_algebra::{
    motion,
    pga3::{Branch, Flat, Line, Origin, Plane, Point},
    Inverse, LeftContraction, OuterProduct, RightContraction,
};

use crate::{
    mesh::{debug, Mesh},
    spatial::Spatial,
};

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

    pub fn debug_point(point: Point, library: &debug::Library) -> Entity {
        Entity::new()
            .spatial(Spatial::identity().translator(motion(Origin::new(), point)))
            .meshes(vec![library.point()])
    }

    pub fn debug_line(line: Line, library: &debug::Library) -> Entity {
        let branch: Branch = line.into();
        Entity::new()
            .spatial(
                Spatial::identity()
                    .translator(motion(
                        Origin::new(),
                        line.left_contraction(Origin::new()).outer_product(line),
                    ))
                    .rotor(motion(Branch::new(1.0, 0.0, 0.0), branch)),
            )
            .meshes(vec![library.line()])
    }

    pub fn debug_plane(plane: Plane, library: &debug::Library) -> Entity {
        // TODO: Inspect, modify project(), add anti_project()?
        let p = Origin::new()
            .right_contraction(plane.inverse())
            .outer_product(plane);
        let flat: Flat = plane.into();
        Entity::new()
            .spatial(
                Spatial::identity()
                    .translator(motion(Origin::new(), p))
                    .rotor(motion(Flat::new(0.0, 0.0, 1.0), flat)),
            )
            .meshes(vec![library.plane()])
    }
}
