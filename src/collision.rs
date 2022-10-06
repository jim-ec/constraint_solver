use std::cell::RefCell;

use cgmath::{InnerSpace, Vector3};

use crate::{constraint::Constraint, debug, rigid::Rigid};

pub const CUBE_VERTICES: [Vector3<f64>; 8] = [
    Vector3::new(-0.5, -0.5, -0.5),
    Vector3::new(0.5, -0.5, -0.5),
    Vector3::new(-0.5, 0.5, -0.5),
    Vector3::new(0.5, 0.5, -0.5),
    Vector3::new(-0.5, -0.5, 0.5),
    Vector3::new(0.5, -0.5, 0.5),
    Vector3::new(-0.5, 0.5, 0.5),
    Vector3::new(0.5, 0.5, 0.5),
];

pub fn ground<'a>(rigid: &'a RefCell<&'a mut Rigid>) -> Vec<Constraint> {
    let mut constraints = Vec::new();

    for vertex in CUBE_VERTICES {
        let position = rigid.borrow().frame.act(vertex);
        if position.z >= 0.0 {
            continue;
        }

        let target_position = Vector3::new(position.x, position.y, 0.0);
        let correction = target_position - position;
        let delta_position = rigid.borrow().delta(position);
        let delta_tangential_position = delta_position - delta_position.project_on(correction);

        constraints.push(Constraint {
            rigid,
            contacts: (position, target_position - 1.0 * delta_tangential_position),
            distance: 0.0,
        })
    }

    constraints
}

impl Rigid {
    fn support(&self, dir: Vector3<f64>) -> Vector3<f64> {
        CUBE_VERTICES
            .into_iter()
            .map(|p| self.frame.act(p))
            .max_by(|a, b| a.dot(dir).total_cmp(&b.dot(dir)))
            .unwrap()
    }

    fn minkowski_support(&self, other: &Rigid, direction: Vector3<f64>) -> Vector3<f64> {
        self.support(direction) - other.support(-direction)
    }

    pub fn gjk(&self, other: &Rigid) -> Option<Tetrahedron> {
        let mut direction = -self.minkowski_support(other, Vector3::unit_x());
        let mut simplex = Simplex::Point(-direction);

        loop {
            let support = self.minkowski_support(other, direction);

            if !same_direction(direction, support) {
                return None;
            }

            match simplex.enclose(support) {
                Ok(simplex) => return Some(simplex),
                Err((next_simplex, next_direction)) => {
                    simplex = next_simplex;
                    direction = next_direction;
                }
            };
        }
    }

    pub fn epa(&self, other: &Rigid, debug_lines: &mut debug::DebugLines) -> Option<Collision> {
        let simplex = self.gjk(other)?;

        let mut polytope = vec![simplex.0, simplex.1, simplex.2, simplex.3];
        let mut faces = vec![(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)];

        // list: vector4(normal, distance), index: min distance
        let (mut normals, mut min_face) = get_face_normals(&polytope, &faces);

        let mut min_normal = Vector3::unit_x();
        let mut min_distance = f64::MAX;

        // TODO: In deep penetration scenarios, EPA seems to never terminate.
        let mut iterations = 0;

        while min_distance == f64::MAX && iterations < 50 {
            min_normal = normals[min_face].0;
            min_distance = normals[min_face].1;

            let support = self.minkowski_support(other, min_normal);
            if polytope.contains(&support)
                && support != simplex.0
                && support != simplex.1
                && support != simplex.2
                && support != simplex.3
            {
                break;
            }

            debug_lines.point(
                support + 0.04 * Vector3::new(rand::random(), rand::random(), rand::random()),
                [0.0, 0.0, 1.0],
            );

            let signed_distance = min_normal.dot(support);

            if (signed_distance - min_distance).abs() > 0.001 {
                min_distance = f64::MAX;
                let mut unique_edges = Vec::new();

                let mut i = 0;
                while i < normals.len() {
                    if same_direction(normals[i].0, support) {
                        add_if_unique_edge(&mut unique_edges, faces[i].0, faces[i].1);
                        add_if_unique_edge(&mut unique_edges, faces[i].1, faces[i].2);
                        add_if_unique_edge(&mut unique_edges, faces[i].2, faces[i].0);

                        let last_face = *faces.last().unwrap();
                        faces[i] = last_face;
                        faces.pop();

                        normals[i] = *normals.last().unwrap();
                        normals.pop();
                    } else {
                        i += 1;
                    }
                }

                let mut new_faces = Vec::new();
                for (i, j) in unique_edges {
                    new_faces.push((i, j, polytope.len()));
                }

                polytope.push(support);

                let (mut new_normals, new_min_face) = get_face_normals(&polytope, &new_faces);
                let mut old_min_distance = f64::MAX;

                #[allow(clippy::needless_range_loop)]
                for i in 0..normals.len() {
                    if normals[i].1 < old_min_distance {
                        old_min_distance = normals[i].1;
                        min_face = i;
                    }
                }

                if new_normals[new_min_face].1 < old_min_distance {
                    min_face = new_min_face + normals.len();
                }

                faces.append(&mut new_faces);
                normals.append(&mut new_normals);
            }

            iterations += 1;
        }

        for &f in &faces {
            debug_lines.line(
                [polytope[f.0], polytope[f.1], polytope[f.2], polytope[f.0]],
                [0.0, 0.0, 1.0],
            );
        }

        debug_lines.line(
            [
                polytope[faces[min_face].0],
                polytope[faces[min_face].1],
                polytope[faces[min_face].2],
                polytope[faces[min_face].0],
            ],
            [1.0, 1.0, 0.0],
        );

        Some(Collision {
            normal: min_normal,
            depth: min_distance + 0.001,
        })
    }
}

/// Simplices up to 3-D.
/// For GJK to work, the invariant that points preceding within the simplex tuple were more recently added
/// to the simplex must be upheld.
#[derive(Debug, Clone, Copy)]
enum Simplex {
    Point(Vector3<f64>),
    Line(Vector3<f64>, Vector3<f64>),
    Triangle(Vector3<f64>, Vector3<f64>, Vector3<f64>),
}

type Tetrahedron = (Vector3<f64>, Vector3<f64>, Vector3<f64>, Vector3<f64>);

impl Simplex {
    fn enclose(self, v: Vector3<f64>) -> Result<Tetrahedron, (Self, Vector3<f64>)> {
        match self {
            Simplex::Point(a) => Err(Self::line(v, a)),
            Simplex::Line(a, b) => Err(Self::triangle(v, a, b)),
            Simplex::Triangle(a, b, c) => Self::tetrahedron(v, a, b, c),
        }
    }

    fn line(a: Vector3<f64>, b: Vector3<f64>) -> (Self, Vector3<f64>) {
        let ab = b - a;
        let ao = -a;

        if same_direction(ab, ao) {
            (Simplex::Line(a, b), ab.cross(ao).cross(ab))
        } else {
            (Simplex::Point(a), ao)
        }
    }

    fn triangle(a: Vector3<f64>, b: Vector3<f64>, c: Vector3<f64>) -> (Self, Vector3<f64>) {
        let ab = b - a;
        let ac = c - a;
        let ao = -a;

        let abc = ab.cross(ac);

        if same_direction(abc.cross(ac), ao) {
            if same_direction(ac, ao) {
                (Simplex::Line(a, c), ac.cross(ao).cross(ac))
            } else {
                Self::line(a, b)
            }
        } else if same_direction(ab.cross(abc), ao) {
            Self::line(a, b)
        } else if same_direction(abc, ao) {
            (Simplex::Triangle(a, b, c), abc)
        } else {
            (Simplex::Triangle(a, c, b), -abc)
        }
    }

    fn tetrahedron(
        a: Vector3<f64>,
        b: Vector3<f64>,
        c: Vector3<f64>,
        d: Vector3<f64>,
    ) -> Result<Tetrahedron, (Self, Vector3<f64>)> {
        let ab = b - a;
        let ac = c - a;
        let ad = d - a;
        let ao = -a;

        let abc = ab.cross(ac);
        let acd = ac.cross(ad);
        let adb = ad.cross(ab);

        if same_direction(abc, ao) {
            Err(Self::triangle(a, b, c))
        } else if same_direction(acd, ao) {
            Err(Self::triangle(a, c, d))
        } else if same_direction(adb, ao) {
            Err(Self::triangle(a, d, b))
        } else {
            Ok((a, b, c, d))
        }
    }
}

pub fn same_direction(a: Vector3<f64>, b: Vector3<f64>) -> bool {
    a.dot(b) > 0.0
}

// #[derive(Debug, Clone, Default)]
// struct Polytope {
//     vertices: Vec<Vector3<f64>>,
//     faces: Vec<usize>, // TODO: Make 3-tuple of usize
// }

// impl Polytope {
//     fn face_normals(&self) -> (Vec<Vector3<f64>>, f64) {
//         self.faces
//             .iter()
//             .tuples()
//             .map(|(&a, &b, &c)| {
//                 let a = self.vertices[a];
//                 let b = self.vertices[b];
//                 let c = self.vertices[c];

//                 let normal = (b - a).cross(c - a).normalize();
//                 let distance = normal.dot(a);

//                 if distance >= 0.0 {
//                     (normal, distance)
//                 } else {
//                     (-normal, -distance)
//                 }
//             })
//             .fold(
//                 (Vec::with_capacity(self.faces.len()), f64::INFINITY),
//                 |(mut normals, minimal_distance), (normal, distance)| {
//                     normals.push(normal);
//                     (normals, minimal_distance.min(distance))
//                 },
//             )
//     }

//     fn push_if_unique(&mut self, edges: &mut Vec<(usize, usize)>, i: usize, j: usize) {
//         //      0--<--3
//         //     / \ B /   A: 2-0
//         //    / A \ /    B: 0-2
//         //   1-->--2

//         if let Some((index, _)) = edges
//             .iter()
//             .find_position(|&&edge| edge == (self.faces[j], self.faces[i]))
//         {
//             edges.remove(index);
//         } else {
//             edges.push((self.faces[i], self.faces[j]));
//         }
//     }
// }

fn add_if_unique_edge(edges: &mut Vec<(usize, usize)>, i: usize, j: usize) {
    //      0--<--3
    //     / \ B /   A: 2-0
    //    / A \ /    B: 0-2
    //   1-->--2

    if let Some(reverse) = edges.iter().position(|&e| e == (j, i)) {
        edges.remove(reverse);
    } else {
        edges.push((i, j));
    }
}

fn get_face_normals(
    polytope: &[Vector3<f64>],
    faces: &[(usize, usize, usize)],
) -> (Vec<(Vector3<f64>, f64)>, usize) {
    let mut normals = Vec::new();
    let mut min_triangle = 0;
    let mut min_distance = f64::MAX;

    for (i, face) in faces.iter().enumerate() {
        let a = polytope[face.0];
        let b = polytope[face.1];
        let c = polytope[face.2];
        let mut normal = (b - a).cross(c - a).normalize();
        let mut distance = normal.dot(a);

        if distance < 0.0 {
            normal *= -1.0;
            distance *= -1.0;
        }

        normals.push((normal, distance));

        if distance < min_distance {
            min_triangle = i;
            min_distance = distance;
        }
    }

    (normals, min_triangle)
}

pub struct Collision {
    pub normal: Vector3<f64>,
    pub depth: f64,
}
