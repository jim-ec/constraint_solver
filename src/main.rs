#![feature(iter_advance_by)]
#![allow(dead_code)]

mod app;
mod camera;
mod entity;
mod world;
mod mesh;
mod numeric;
mod renderer;
mod shapes;
mod spatial;
mod simplex;
mod rigid;
mod frame;
mod constraint;
mod collision;
mod solver;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
