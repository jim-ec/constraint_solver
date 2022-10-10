use cgmath::{InnerSpace, Vector3};

/// Simplices up to 3-D.
/// For GJK to work, the invariant that points preceding within the simplex tuple were more recently added
/// to the simplex must be upheld.
#[derive(Debug, Clone, Copy)]
pub enum Simplex {
    Point(Vector3<f64>),
    Line(Vector3<f64>, Vector3<f64>),
    Triangle(Vector3<f64>, Vector3<f64>, Vector3<f64>),
}

pub type Tetrahedron = (Vector3<f64>, Vector3<f64>, Vector3<f64>, Vector3<f64>);

impl Simplex {
    pub fn enclose(self, v: Vector3<f64>) -> Result<Tetrahedron, (Self, Vector3<f64>)> {
        match self {
            Simplex::Point(a) => Err(Self::line(v, a)),
            Simplex::Line(a, b) => Err(Self::triangle(v, a, b)),
            Simplex::Triangle(a, b, c) => Self::tetrahedron(v, a, b, c),
        }
    }

    fn line(a: Vector3<f64>, b: Vector3<f64>) -> (Self, Vector3<f64>) {
        let ab = b - a;
        let ao = -a;

        if ab.dot(ao) > 0.0 {
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

        if abc.cross(ac).dot(ao) > 0.0 {
            if ac.dot(ao) > 0.0 {
                (Simplex::Line(a, c), ac.cross(ao).cross(ac))
            } else {
                Self::line(a, b)
            }
        } else if ab.cross(abc).dot(ao) > 0.0 {
            Self::line(a, b)
        } else if abc.dot(ao) > 0.0 {
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

        if abc.dot(ao) > 0.0 {
            Err(Self::triangle(a, b, c))
        } else if acd.dot(ao) > 0.0 {
            Err(Self::triangle(a, c, d))
        } else if adb.dot(ao) > 0.0 {
            Err(Self::triangle(a, d, b))
        } else {
            Ok((a, b, c, d))
        }
    }
}
