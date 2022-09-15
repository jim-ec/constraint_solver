struct Camera {
    view: mat4x4<f32>,
    inverse_view: mat4x4<f32>,
    proj: mat4x4<f32>,
    inverse_prog: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

struct Fragment {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(2) camera_distance: f32,
}

let PI = 3.14159265358979323846264338327950288;
let MAX = 3.40282347e+38;

@vertex
fn vs_main(@builtin(vertex_index) id: u32) -> Fragment {
    var frag: Fragment;

    let distant = 10.0e+3;
    var positions = array(
        vec4(-distant, 0.0, -distant, 1.0),
        vec4(-distant, 0.0, distant, 1.0),
        vec4(distant, 0.0, 0.0, 1.0),
    );
    let position = positions[id];

    frag.clip_position = camera.proj * camera.view * position;
    frag.position = position.xyz / position.w;

    let camera_position = camera.inverse_view * vec4(0.0, 0.0, 0.0, 1.0);
    frag.camera_distance = length(camera_position.xyz / camera_position.w);

    return frag;
}

fn axis(position: vec3<f32>) -> vec3<f32> {
    let width = min(fwidth(position.xz), vec2(1.0));

    if position.z > -width.y && position.z < width.y {
        return vec3(1.0, 0.2, 0.2);
    }
    if position.x > -width.x && position.x < width.x {
        return vec3(0.2, 1.0, 0.2);
    }
    return vec3(1.0);
}

fn grid(position: vec3<f32>, phase: f32) -> f32 {
    let position = position.xz / phase;
    let grid = abs(fract(position - 0.5) - 0.5) / fwidth(position);
    return 1.0 - min(min(grid.x, grid.y), 1.0);
}

fn radius_attenuation(frag: Fragment, visible_radius: f32) -> f32 {
    let len = length(frag.position);
    return exp(-len * len / (visible_radius * visible_radius));
}

fn tilt_attenuation(falloff: f32) -> f32 {
    let attenuation = 1.0 - abs(dot(vec4(0.0, 1.0, 0.0, 0.0), normalize(camera.view * vec4(0.0, 1.0, 0.0, 0.0))));
    return pow(attenuation, falloff);
}

fn distance_attenuation(frag: Fragment, falloff: f32) -> f32 {
    return pow(0.1 * frag.camera_distance, -falloff);
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    var color = vec4(vec3(1.0), 0.0);

    color.a += 0.1 * grid(frag.position, 1.0);
    color.a += 0.4 * grid(frag.position, 10.0);
    color.a += 0.8 * grid(frag.position, 50.0);

    color *= vec4(axis(frag.position), 1.0);

    color.a *= tilt_attenuation(0.4);
    color.a *= radius_attenuation(frag, 250.0);
    color.a *= distance_attenuation(frag, 0.5);

    return color;
    // return vec4(vec3(color.a), 1.0);
}
