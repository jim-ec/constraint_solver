struct Camera {
    view: mat4x4<f32>,
    proj: mat4x4<f32>,
}

@group(0) @binding(0) var<uniform> camera: Camera;
@group(1) @binding(0) var depth_texture: texture_2d<f32>;
@group(1) @binding(1) var depth_sampler: sampler;

struct Vertex {
    @builtin(vertex_index) index: u32,
    @location(0) position: vec4<f32>,
    @location(1) color: vec3<f32>,
}

struct Fragment {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) color: vec3<f32>,
    @location(1) depth: f32,
}

@vertex
fn vs_main(vertex: Vertex) -> Fragment {
    var frag: Fragment;

    var ps = array(
        vec4(1.0, 1.0, 0.0, 1.0),
        vec4(-1.0, 1.0, 0.0, 1.0),
        vec4(-1.0, -1.0, 0.0, 1.0),

        vec4(1.0, 1.0, 0.0, 1.0),
        vec4(-1.0, -1.0, 0.0, 1.0),
        vec4(1.0, -1.0, 0.0, 1.0),
    );

    // frag.clip_position = camera.proj * camera.view * vertex.position;
    // frag.depth = frag.clip_position.z;
    // frag.color = vertex.color;
    frag.clip_position = ps[vertex.index];
    return frag;
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    // TODO: Compare against depth
    let depth = textureSample(depth_texture, depth_sampler, frag.clip_position.xy);
    
    // return vec4(1.0, 0.0, 0.0, 1.0);
    // return vec4(vec3(depth / 100.0), 1.0);
    return vec4(vec3(depth.r) * 10.0, 1.0);

    // if depth < frag.depth {
    //     return vec4(1.0, 0.0, 0.0, 1.0);
    // }
    // else {
    //     return vec4(frag.color, 1.0);
    // }
}
