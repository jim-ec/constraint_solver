use cgmath::{vec3, InnerSpace, Matrix3, Matrix4, Vector3, Zero};

use super::Polytope;

#[derive(Default, Debug)]
struct Polyhedron {
    vertices: Vec<Vector3<f64>>,
    faces: Vec<Face>,
}

#[derive(Debug)]
struct Face {
    normal: Vector3<f64>,
    displacement: f64,
    vertices: Vec<usize>,
}

#[derive(Debug, Clone, Copy)]
pub struct RigidMetrics {
    pub mass: f64,
    pub volume: f64,
    pub center_of_mass: Vector3<f64>,
    pub inertia_tensor: Matrix3<f64>,
}

pub fn rigid_metrics(polytope: &Polytope, density: f64) -> RigidMetrics {
    let mut polyhedron = Polyhedron {
        vertices: polytope.vertices.clone(),
        faces: vec![],
    };

    for (i, plane) in polytope.planes() {
        polyhedron.faces.push(Face {
            normal: plane.normal,
            displacement: plane.constant(),
            vertices: polytope.faces[i].clone(),
        });
    }

    let integrals = volume_integrals(&polyhedron);

    let m = density * integrals.t0;
    let r = integrals.t1 / integrals.t0;

    let mut j = Matrix3::zero();

    // Compute inertia tensor
    j.x.x = density * (integrals.t2.y + integrals.t2.z);
    j.y.y = density * (integrals.t2.z + integrals.t2.x);
    j.z.z = density * (integrals.t2.x + integrals.t2.y);
    j.x.y = -density * integrals.tp.x;
    j.y.z = -density * integrals.tp.y;
    j.z.x = -density * integrals.tp.z;
    j.y.x = j.x.y;
    j.z.y = j.y.z;
    j.x.z = j.z.x;

    // Translate inertia tensor to center of mass
    j.x.x -= m * (r.y * r.y + r.z * r.z);
    j.y.y -= m * (r.z * r.z + r.x * r.x);
    j.z.z -= m * (r.x * r.x + r.y * r.y);
    j.x.y += m * r.x * r.y;
    j.y.z += m * r.y * r.z;
    j.z.x += m * r.z * r.x;
    j.y.x = j.x.y;
    j.z.y = j.y.z;
    j.x.z = j.z.x;

    RigidMetrics {
        mass: m,
        volume: integrals.t0,
        center_of_mass: r,
        inertia_tensor: j,
    }
}

#[derive(Debug, Clone, Copy)]
struct VolumeIntegrals {
    t0: f64,
    t1: Vector3<f64>,
    t2: Vector3<f64>,
    tp: Vector3<f64>,
}

#[derive(Debug, Default, Clone, Copy)]
struct FaceIntegrals {
    a: f64,
    b: f64,
    c: f64,
    aa: f64,
    bb: f64,
    cc: f64,
    aaa: f64,
    bbb: f64,
    ccc: f64,
    aab: f64,
    bbc: f64,
    cca: f64,
}

#[derive(Debug, Default, Clone, Copy)]
struct ProjectionIntegrals {
    e: f64,
    a: f64,
    b: f64,
    aa: f64,
    ab: f64,
    bb: f64,
    aaa: f64,
    aab: f64,
    abb: f64,
    bbb: f64,
}

impl Default for VolumeIntegrals {
    fn default() -> Self {
        Self {
            t0: 0.0,
            t1: Vector3::zero(),
            t2: Vector3::zero(),
            tp: Vector3::zero(),
        }
    }
}

fn volume_integrals(poly: &Polyhedron) -> VolumeIntegrals {
    let mut t = VolumeIntegrals::default();

    for face in &poly.faces {
        let n = face.normal.map(f64::abs);

        let gamma = if n.x > n.y && n.x > n.z {
            0
        } else if n.y > n.z {
            1
        } else {
            2
        };
        let alpha = (gamma + 1) % 3;
        let beta = (alpha + 1) % 3;

        let f = face_integrals(poly, face, alpha, beta, gamma);

        t.t0 += face.normal.x
            * if alpha == 0 {
                f.a
            } else if beta == 0 {
                f.b
            } else {
                f.c
            };

        t.t1[alpha] += face.normal[alpha] * f.aa;
        t.t1[beta] += face.normal[beta] * f.bb;
        t.t1[gamma] += face.normal[gamma] * f.cc;
        t.t2[alpha] += face.normal[alpha] * f.aaa;
        t.t2[beta] += face.normal[beta] * f.bbb;
        t.t2[gamma] += face.normal[gamma] * f.ccc;
        t.tp[alpha] += face.normal[alpha] * f.aab;
        t.tp[beta] += face.normal[beta] * f.bbc;
        t.tp[gamma] += face.normal[gamma] * f.cca;
    }

    t.t1 /= 2.0;
    t.t2 /= 3.0;
    t.tp /= 2.0;

    t
}

fn face_integrals(
    poly: &Polyhedron,
    f: &Face,
    alpha: usize,
    beta: usize,
    gamma: usize,
) -> FaceIntegrals {
    let p = projection_integrals(poly, f, alpha, beta);

    let w = f.displacement;
    let n = f.normal;
    let k1 = 1.0 / n[gamma];
    let k2 = k1 * k1;
    let k3 = k2 * k1;
    let k4 = k3 * k1;

    FaceIntegrals {
        a: k1 * p.a,
        b: k1 * p.b,
        c: -k2 * (n[alpha] * p.a + n[beta] * p.b + w * p.e),

        aa: k1 * p.aa,
        bb: k1 * p.bb,
        cc: k3
            * (sq(n[alpha]) * p.aa
                + 2.0 * n[alpha] * n[beta] * p.ab
                + sq(n[beta]) * p.bb
                + w * (2.0 * (n[alpha] * p.a + n[beta] * p.b) + w * p.e)),

        aaa: k1 * p.aaa,
        bbb: k1 * p.bbb,
        ccc: -k4
            * (cb(n[alpha]) * p.aaa
                + 3.0 * sq(n[alpha]) * n[beta] * p.aab
                + 3.0 * n[alpha] * sq(n[beta]) * p.abb
                + cb(n[beta]) * p.bbb
                + 3.0
                    * w
                    * (sq(n[alpha]) * p.aa + 2.0 * n[alpha] * n[beta] * p.ab + sq(n[beta]) * p.bb)
                + w * w * (3.0 * (n[alpha] * p.a + n[beta] * p.b) + w * p.e)),

        aab: k1 * p.aab,
        bbc: -k2 * (n[alpha] * p.abb + n[beta] * p.bbb + w * p.bb),
        cca: k3
            * (sq(n[alpha]) * p.aaa
                + 2.0 * n[alpha] * n[beta] * p.aab
                + sq(n[beta]) * p.abb
                + w * (2.0 * (n[alpha] * p.aa + n[beta] * p.ab) + w * p.a)),
    }
}

/// compute various integrations over projection of face
fn projection_integrals(
    poly: &Polyhedron,
    f: &Face,
    alpha: usize,
    beta: usize,
) -> ProjectionIntegrals {
    let mut integrals = ProjectionIntegrals::default();

    // TODO: Use circulcating tuple windows
    for i in 0..f.vertices.len() {
        let a0 = poly.vertices[f.vertices[i]][alpha];
        let b0 = poly.vertices[f.vertices[i]][beta];
        let a1 = poly.vertices[f.vertices[(i + 1) % f.vertices.len()]][alpha];
        let b1 = poly.vertices[f.vertices[(i + 1) % f.vertices.len()]][beta];
        let da = a1 - a0;
        let db = b1 - b0;
        let a0_2 = a0 * a0;
        let a0_3 = a0_2 * a0;
        let a0_4 = a0_3 * a0;
        let b0_2 = b0 * b0;
        let b0_3 = b0_2 * b0;
        let b0_4 = b0_3 * b0;
        let a1_2 = a1 * a1;
        let a1_3 = a1_2 * a1;
        let b1_2 = b1 * b1;
        let b1_3 = b1_2 * b1;

        let c_1 = a1 + a0;
        let c_a = a1 * c_1 + a0_2;
        let c_aa = a1 * c_a + a0_3;
        let c_aaa = a1 * c_aa + a0_4;
        let c_b = b1 * (b1 + b0) + b0_2;
        let c_bb = b1 * c_b + b0_3;
        let c_bbb = b1 * c_bb + b0_4;
        let c_ab = 3.0 * a1_2 + 2.0 * a1 * a0 + a0_2;
        let k_ab = a1_2 + 2.0 * a1 * a0 + 3.0 * a0_2;
        let c_aab = a0 * c_ab + 4.0 * a1_3;
        let k_aab = a1 * k_ab + 4.0 * a0_3;
        let c_abb = 4.0 * b1_3 + 3.0 * b1_2 * b0 + 2.0 * b1 * b0_2 + b0_3;
        let k_abb = b1_3 + 2.0 * b1_2 * b0 + 3.0 * b1 * b0_2 + 4.0 * b0_3;

        integrals.e += db * c_1;
        integrals.a += db * c_a;
        integrals.aa += db * c_aa;
        integrals.aaa += db * c_aaa;
        integrals.b += da * c_b;
        integrals.bb += da * c_bb;
        integrals.bbb += da * c_bbb;
        integrals.ab += db * (b1 * c_ab + b0 * k_ab);
        integrals.aab += db * (b1 * c_aab + b0 * k_aab);
        integrals.abb += da * (a1 * c_abb + a0 * k_abb);
    }

    integrals.e /= 2.0;
    integrals.a /= 6.0;
    integrals.aa /= 12.0;
    integrals.aaa /= 20.0;
    integrals.b /= -6.0;
    integrals.bb /= -12.0;
    integrals.bbb /= -20.0;
    integrals.ab /= 24.0;
    integrals.aab /= 60.0;
    integrals.abb /= -60.0;

    integrals
}

fn sq(x: f64) -> f64 {
    x.powi(2)
}

fn cb(x: f64) -> f64 {
    x.powi(3)
}
