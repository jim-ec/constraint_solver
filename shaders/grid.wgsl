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
    @location(2) camera_position: vec3<f32>,
}

let PI = 3.14159265358979323846264338327950288;
let MAX = 3.40282347e+38;

@vertex
fn vs_main(@builtin(vertex_index) id: u32) -> Fragment {
    var frag: Fragment;

    // let distant = 10.0e+10;
    let distant = 10.0e+3;
    var positions = array(
        vec4(-distant, -distant, 0.0, 1.0),
        vec4(-distant, distant, 0.0, 1.0),
        vec4(distant, 0.0, 0.0, 1.0),
    );
    let position = positions[id];

    frag.clip_position = camera.proj * camera.view * position;
    frag.position = position.xyz;

    let camera_position = camera.inverse_view * vec4(0.0, 0.0, 0.0, 1.0);
    frag.camera_position = camera_position.xyz;

    return frag;
}

@fragment
fn fs_main(frag: Fragment) -> @location(0) vec4<f32> {
    let camera_distance = distance(frag.position, frag.camera_position);
    let distance_attenuation = clamp(25.0 / camera_distance, 0.0, 1.0);

    let tilt_attenuation = abs(dot(vec4(0.0, 0.0, 1.0, 0.0), camera.view * vec4(0.0, 1.0, 0.0, 0.0)));
    
    var point_x = abs(frag.position.x) % 1.0;
    var point_y = abs(frag.position.y) % 1.0;
    point_x = 0.5 - abs(0.5 - point_x);
    point_y = 0.5 - abs(0.5 - point_y);

    let phase_x = u32(round(abs(frag.position.x) - point_x));
    let phase_y = u32(round(abs(frag.position.y) - point_y));

    let width = 0.0018 * camera_distance;

    if min(point_x, point_y) < width {
        var color = vec3(0.2);
        if phase_x == 0u && point_x < width {
            color =  vec3(1.0, 0.2, 0.2);
        }
        else if phase_y == 0u && point_y < width {
            color =  vec3(0.2, 1.0, 0.2);
        }
        else if phase_x % 10u == 0u && point_x < width {
            color =  vec3(1.0);
        }
        else if phase_y % 10u == 0u && point_y < width {
            color =  vec3(1.0);
        }
        return vec4(color, pow(tilt_attenuation, 2.0) * pow(distance_attenuation, 2.0));
    }
    else {
        return vec4(0.0, 0.0, 0.0, 0.0);
    }
}
