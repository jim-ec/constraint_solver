#![feature(iter_advance_by)]

mod app;
mod camera;
mod collision;
mod constraint;
mod entity;
mod frame;
mod mesh;
mod numeric;
mod renderer;
mod rigid;
mod simplex;
mod solver;
mod spatial;
mod world;
mod line_debugger;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
