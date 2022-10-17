#![allow(unused)]

mod app;
mod camera;
mod collision;
mod constraint;
mod debug;
mod frame;
mod geometry;
mod mesh;
mod renderer;
mod rigid;
mod solver;
mod world;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
