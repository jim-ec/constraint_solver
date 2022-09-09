#![feature(iter_advance_by)]
#![allow(dead_code)]

mod app;
mod camera;
mod entity;
mod game;
mod mesh;
mod numeric;
mod renderer;
mod shapes;
mod spatial;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
