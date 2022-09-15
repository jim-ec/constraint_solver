struct Camera {
    view: mat4x4<f32>,
    inverse_view: mat4x4<f32>,
    proj: mat4x4<f32>,
    inverse_proj: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

struct Fragment {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) near_point: vec3<f32>,
    @location(1) far_point: vec3<f32>,
}

fn unproject(p: vec3<f32>) -> vec3<f32> {
    let unprojected_point = camera.inverse_view * camera.inverse_proj * vec4(p, 1.0);
    return unprojected_point.xyz / unprojected_point.w;
}

@vertex
fn vs_main(@builtin(vertex_index) id: u32) -> Fragment {
    var frag: Fragment;

    var positions = array(
        vec4(1.0, -1.0, 0.0, 1.0),
        vec4(-1.0, 1.0, 0.0, 1.0),
        vec4(-1.0, -1.0, 0.0, 1.0),
        vec4(1.0, 1.0, 0.0, 1.0),
        vec4(-1.0, 1.0, 0.0, 1.0),
        vec4(1.0, -1.0, 0.0, 1.0),
    );
    let position = positions[id];

    frag.near_point = unproject(vec3(position.xy, 0.0));
    frag.far_point = unproject(vec3(position.xy, 1.0));

    frag.clip_position = position;

    return frag;
}

fn grid(position: vec3<f32>, scale: f32) -> vec4<f32> {
    let coord = position.xz * scale; // use the scale variable to set the distance between the lines
    let derivative = fwidth(coord);
    let grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    let grid_line = min(grid.x, grid.y);
    let minimumz = min(derivative.y, 1.0);
    let minimumx = min(derivative.x, 1.0);
    var color = vec4(0.2, 0.2, 0.2, 1.0 - min(grid_line, 1.0));
    // z axis
    if position.x > -0.1 * minimumx && position.x < 0.1 * minimumx {
        color.z = 1.0;
    }
    // x axis
    if position.z > -0.1 * minimumz && position.z < 0.1 * minimumz {
        color.x = 1.0;
    }
    return color;
}

fn computeDepth(pos: vec3<f32>) -> f32 {
    let clip_space_pos = camera.proj * camera.view * vec4(pos.xyz, 1.0);
    return clip_space_pos.z / clip_space_pos.w;
}

fn computeLinearDepth(pos: vec3<f32>) -> f32 {
    let near = 0.01;
    let far = 100.0;

    let clip_space_pos = camera.proj * camera.view * vec4(pos.xyz, 1.0);
    let clip_space_depth = (clip_space_pos.z / clip_space_pos.w); // put back between -1 and 1
    let linearDepth = (2.0 * near * far) / (far + near - clip_space_depth * (far - near)); // get linear value between 0.01 and 100
    return linearDepth / far; // normalize
}

struct Output {
    @location(0) color: vec4<f32>,
    @builtin(frag_depth) depth: f32,
}

@fragment
fn fs_main(frag: Fragment) -> Output {
    let t = -frag.near_point.y / (frag.far_point.y - frag.near_point.y);
    let position = frag.near_point + t * (frag.far_point - frag.near_point);
    
    var out: Output;
    out.color = (grid(position, 1.0) + grid(position, 10.0)) * f32(t > 0.0);
    out.depth = computeDepth(position);

    let linearDepth = computeLinearDepth(position);
    let fading = max(0.0, (0.5 - linearDepth));
    out.color.a *= fading;

    return out;
}
