mod app;
mod camera;
mod collision;
mod constraint;
mod frame;
mod line_debugger;
mod mesh;
mod renderer;
mod rigid;
mod solver;
mod world;

#[async_std::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    app::run().await
}
