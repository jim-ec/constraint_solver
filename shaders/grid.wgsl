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

    return frag;
}

fn axis(position: vec3<f32>) -> vec3<f32> {
    let width = min(fwidth(2.0 * position.xz), vec2(2.0));

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
    let grid = abs(fract(position - 0.5) - 0.5) / fwidth(2.0 * position);
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

fn perspective_distortion_attenuation(frag: Fragment, amount: f32) -> f32 {
    let change = abs(fwidth(frag.position.x) + fwidth(frag.position.z));
    return 1.0 / (amount * change);
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    var color = vec4(vec3(1.0), 0.0);

    color.a += grid(frag.position, 1.0);
    color.a += grid(frag.position, 10.0);
    color.a += grid(frag.position, 100.0);
    color.a += grid(frag.position, 1000.0);
    color.a /= 4.0;
    color.a = pow(color.a, 4.0);

    color *= vec4(axis(frag.position), 1.0);

    color.a *= tilt_attenuation(0.4);
    color.a *= radius_attenuation(frag, 2000.0);
    color.a *= perspective_distortion_attenuation(frag, 0.5);

    return color;
}
