use cgmath::{InnerSpace, Vector3};

#[derive(Debug, Clone, Copy)]
pub struct Plane {
    pub normal: Vector3<f64>,
    pub displacement: f64,
}

impl Plane {
    /// Construct a plane from three points.
    pub fn from_points(points: [Vector3<f64>; 3]) -> Plane {
        let normal = (points[1] - points[0])
            .cross(points[2] - points[0])
            .normalize();
        Plane {
            normal,
            displacement: normal.dot(points[0]),
        }
    }

    /// Construct a plane from a point and a normal vector.
    pub fn from_point_normal(point: Vector3<f64>, normal: Vector3<f64>) -> Plane {
        let mut displacement = point.project_on(normal).magnitude();
        if point.dot(normal) < 0.0 {
            displacement *= -1.0;
        }
        Plane {
            normal,
            displacement,
        }
    }

    /// Compute the distance of the plane to an arbitrary vector.
    pub fn distance(self, point: Vector3<f64>) -> f64 {
        self.normal.dot(point) - self.displacement
    }

    /// Project a vector onto the plane.
    pub fn project(self, point: Vector3<f64>) -> Vector3<f64> {
        point - self.distance(point) * self.normal
    }
}
