struct Camera {
    view: mat4x4<f32>,
    proj: mat4x4<f32>,
}

struct Mesh {
    transform: mat4x4<f32>,
    color: vec3<f32>,
    lit: u32,
}

@group(0) @binding(0) var<uniform> camera: Camera;
@group(1) @binding(0) var<uniform> mesh: Mesh;

struct Vertex {
    @location(0) position: vec4<f32>,
    @location(1) color: vec3<f32>,
}

struct Fragment {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) world_position: vec3<f32>,
    @location(3) color: vec3<f32>,
}

let PI = 3.14159265358979323846264338327950288;
let TAU = 6.28318530717958647692528676655900577;
let SQRT2 = 1.41421356237309504880168872420969808;
let E = 2.71828182845904523536028747135266250;

@vertex
fn vs_main(vertex: Vertex) -> Fragment {
    var frag: Fragment;

    // Homogenize position.
    let position = vec4<f32>(vertex.position.xyz / vertex.position.w, 1.0);
    frag.world_position = (mesh.transform * position).xyz;
    frag.position = (camera.view * mesh.transform * position).xyz;
    frag.clip_position = camera.proj * camera.view * mesh.transform * position;

    frag.color = vertex.color;

    return frag;
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    let ambient_light = 0.005;
    let light_intensity = 2.0;
    
    // Compute normal based on positional derivatives.
    // A normal vector of (0, 0, 1) points toward the viewer.
    let n = normalize(cross(dpdy(frag.position), dpdx(frag.position)));

    let v = normalize(vec3<f32>(0.0, 0.0, 1.0) - frag.position);
    let nov = dot(n, v);

    var color = mesh.color * frag.color;

    if (bool(mesh.lit)) {
        color = light_intensity * color * nov + ambient_light;
    }

    return vec4<f32>(color, 1.0);

    // // Debug normals:
    // var c = n / 2.0 + 0.5;
    // c *= c;
    // return vec4<f32>(c, 1.0);
}
