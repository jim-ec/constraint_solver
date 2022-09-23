mod app;
mod camera;
mod collision;
mod constraint;
mod entity;
mod frame;
mod line_debugger;
mod mesh;
mod numeric;
mod renderer;
mod rigid;
mod simplex;
mod solver;
mod spatial;
mod world;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
