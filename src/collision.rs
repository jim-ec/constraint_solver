use std::cell::RefCell;

use cgmath::{InnerSpace, Vector3};

use crate::{constraint::Constraint, rigid::Rigid};

const CUBE_VERTICES: [Vector3<f64>; 8] = [
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
    #![allow(dead_code)]

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

    pub fn gjk(&self, other: &Rigid) -> bool {
        let mut support = self.minkowski_support(other, Vector3::unit_x());
        let mut simplex = Simplex::Point(support);

        let mut direction = -support;

        loop {
            support = self.minkowski_support(other, direction);

            // TODO: Use `!same_direction()`?
            if support.dot(direction) <= 0.0 {
                return false;
            }

            simplex = simplex.extend(support);

            simplex = simplex.next(&mut direction);
            if let Simplex::Tetrahedron(_, _, _, _) = simplex {
                return true;
            }
        }
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
    Tetrahedron(Vector3<f64>, Vector3<f64>, Vector3<f64>, Vector3<f64>),
}

impl Simplex {
    fn extend(self, v: Vector3<f64>) -> Self {
        match self {
            Simplex::Point(a) => Simplex::Line(v, a),
            Simplex::Line(a, b) => Simplex::Triangle(v, a, b),
            Simplex::Triangle(a, b, c) => Simplex::Tetrahedron(v, a, b, c),
            Simplex::Tetrahedron(_, _, _, _) => panic!(),
        }
    }

    #[must_use]
    fn next(self, direction: &mut Vector3<f64>) -> Self {
        match self {
            Simplex::Point(a) => Simplex::Point(a),
            Simplex::Line(a, b) => Self::line(a, b, direction),
            Simplex::Triangle(a, b, c) => Self::triangle(a, b, c, direction),
            Simplex::Tetrahedron(a, b, c, d) => Self::tetrahedron(a, b, c, d, direction),
        }
    }

    fn line(a: Vector3<f64>, b: Vector3<f64>, direction: &mut Vector3<f64>) -> Self {
        let ab = b - a;
        let ao = -a;

        if same_direction(ab, ao) {
            *direction = ab.cross(ao).cross(ab);
            Simplex::Line(a, b)
        } else {
            *direction = ao;
            Simplex::Point(a)
        }
    }

    fn triangle(
        a: Vector3<f64>,
        b: Vector3<f64>,
        c: Vector3<f64>,
        direction: &mut Vector3<f64>,
    ) -> Self {
        let ab = b - a;
        let ac = c - a;
        let ao = -a;

        let abc = ab.cross(ac);

        if same_direction(abc.cross(ac), ao) {
            if same_direction(ac, ao) {
                *direction = ac.cross(ao).cross(ac);
                Simplex::Line(a, c)
            } else {
                Self::line(a, b, direction)
            }
        } else if same_direction(ab.cross(abc), ao) {
            Self::line(a, b, direction)
        } else if same_direction(abc, ao) {
            *direction = abc;
            Simplex::Triangle(a, b, c)
        } else {
            *direction = -abc;
            Simplex::Triangle(a, c, b)
        }
    }

    fn tetrahedron(
        a: Vector3<f64>,
        b: Vector3<f64>,
        c: Vector3<f64>,
        d: Vector3<f64>,
        direction: &mut Vector3<f64>,
    ) -> Self {
        let ab = b - a;
        let ac = c - a;
        let ad = d - a;
        let ao = -a;

        let abc = ab.cross(ac);
        let acd = ac.cross(ad);
        let adb = ad.cross(ab);

        if same_direction(abc, ao) {
            Self::triangle(a, b, c, direction)
        } else if same_direction(acd, ao) {
            Self::triangle(a, c, d, direction)
        } else if same_direction(adb, ao) {
            Self::triangle(a, d, b, direction)
        } else {
            Self::Tetrahedron(a, b, c, d)
        }
    }
}

fn same_direction(direction: Vector3<f64>, ao: Vector3<f64>) -> bool {
    direction.dot(ao) > 0.0
}
