struct Camera {
    view: mat4x4<f32>,
    proj: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;

struct Vertex {
    @location(0) position: vec3<f32>,
    @location(1) color: vec3<f32>,
}

struct Fragment {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) position: vec3<f32>,
    @location(1) color: vec3<f32>,
}

@vertex
fn vs_main(vertex: Vertex) -> Fragment {
    var frag: Fragment;

    let position = camera.view * vec4(vertex.position, 1.0);
    frag.clip_position = camera.proj * position;
    frag.position = position.xyz / position.w;

    frag.color = vertex.color;

    return frag;
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    return vec4(frag.color, 1.0);
}
