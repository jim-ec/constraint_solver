use std::{
    collections::{HashMap, HashSet},
    iter::repeat,
    ops::Add,
};

use geometric_algebra::{
    pga3::{Point, Scalar},
    Dual, Magnitude,
};

#[derive(Debug, Clone, Copy, Default)]
pub struct Triangle(pub usize, pub usize, pub usize);

#[derive(Debug, Clone, Default)]
pub struct Shape {
    pub points: Vec<Point>,
    pub triangles: Vec<Triangle>,
}

pub fn normalize(p: Point) -> Point {
    p / Scalar { g0: p.g0[3].abs() }
}

/// Projects a point onto the unit sphere if its dual has a non-degenerate magnitude.
pub fn unitize(p: Point) -> Point {
    let length = p.dual().magnitude();
    Point {
        g0: [
            p.g0[0] / length.g0,
            p.g0[1] / length.g0,
            p.g0[2] / length.g0,
            p.g0[3],
        ]
        .into(),
    }
}

pub fn lerp(p: Point, q: Point, t: f32) -> Point {
    let p = p / p.magnitude();
    let q = q / q.magnitude();
    Scalar::new(1.0 - t) * p + Scalar::new(t) * q
}

impl Shape {
    pub fn triangle() -> Self {
        Shape {
            points: vec![
                Point::at(0.0, 0.0, 0.0),
                Point::at(1.0, 0.0, 0.0),
                Point::at(0.0, 1.0, 0.0),
            ],
            triangles: vec![Triangle(0, 1, 2)],
        }
    }

    pub fn quad() -> Self {
        Shape {
            points: vec![
                Point::at(0.0, 0.0, 0.0),
                Point::at(1.0, 0.0, 0.0),
                Point::at(0.0, 1.0, 0.0),
                Point::at(1.0, 1.0, 0.0),
            ],
            triangles: vec![Triangle(0, 1, 2), Triangle(2, 1, 3)],
        }
    }

    pub fn cube() -> Self {
        Shape {
            points: vec![
                Point::at(0.0, 0.0, 0.0),
                Point::at(0.0, 0.0, 1.0),
                Point::at(0.0, 1.0, 0.0),
                Point::at(0.0, 1.0, 1.0),
                Point::at(1.0, 0.0, 0.0),
                Point::at(1.0, 0.0, 1.0),
                Point::at(1.0, 1.0, 0.0),
                Point::at(1.0, 1.0, 1.0),
            ],
            triangles: vec![
                Triangle(0, 1, 3),
                Triangle(0, 3, 2),
                Triangle(0, 4, 5),
                Triangle(0, 5, 1),
                Triangle(0, 6, 4),
                Triangle(0, 2, 6),
                Triangle(1, 5, 7),
                Triangle(1, 7, 3),
                Triangle(2, 7, 6),
                Triangle(2, 3, 7),
                Triangle(4, 7, 5),
                Triangle(4, 6, 7),
            ],
        }
    }

    pub fn icosahedron() -> Self {
        let phi = (1.0 + 5.0_f32.sqrt()) / 2.0;
        Shape {
            points: vec![
                Point::at(phi, 1.0, 0.0),
                Point::at(phi, -1.0, 0.0),
                Point::at(-phi, 1.0, 0.0),
                Point::at(-phi, -1.0, 0.0),
                Point::at(0.0, phi, 1.0),
                Point::at(0.0, phi, -1.0),
                Point::at(0.0, -phi, 1.0),
                Point::at(0.0, -phi, -1.0),
                Point::at(1.0, 0.0, phi),
                Point::at(-1.0, 0.0, phi),
                Point::at(1.0, 0.0, -phi),
                Point::at(-1.0, 0.0, -phi),
            ],
            triangles: vec![
                Triangle(0, 5, 4),
                Triangle(2, 4, 5),
                Triangle(1, 6, 7),
                Triangle(3, 7, 6),
                Triangle(1, 0, 8),
                Triangle(0, 1, 10),
                Triangle(2, 3, 9),
                Triangle(3, 2, 11),
                Triangle(4, 9, 8),
                Triangle(6, 8, 9),
                Triangle(5, 10, 11),
                Triangle(7, 11, 10),
                Triangle(0, 4, 8),
                Triangle(0, 10, 5),
                Triangle(2, 9, 4),
                Triangle(2, 5, 11),
                Triangle(1, 8, 6),
                Triangle(1, 7, 10),
                Triangle(3, 6, 9),
                Triangle(3, 11, 7),
            ],
        }
    }

    pub fn tessellate(self, count: usize) -> (Shape, AdjacencyGraph) {
        assert!(count >= 1, "Subdivision count must be positive");

        let mut points = self.points;
        let mut triangles = Vec::new();
        let mut tessellated_edges = HashMap::new();
        let mut adjacencies = AdjacencyGraph::default();
        adjacencies
            .vertices
            .extend(repeat(HashSet::new()).take(points.len()));

        for triangle in self.triangles {
            // Tessellate edges
            for edge in [
                (triangle.0, triangle.1),
                (triangle.1, triangle.2),
                (triangle.2, triangle.0),
            ] {
                let anti_edge = (edge.1, edge.0);

                if !tessellated_edges.contains_key(&edge)
                    && !tessellated_edges.contains_key(&anti_edge)
                {
                    // Tessellate edge
                    let d0 = points[edge.0].dir();
                    let d1 = points[edge.1].dir();
                    let step = (d1 - d0) / Scalar::new(count as f32);
                    let mut d = d0;
                    let mut indices = Vec::with_capacity(count - 1);
                    points.reserve(count - 1);
                    for _ in 1..count {
                        d += step;
                        indices.push(points.len());
                        points.push(d.point());
                    }
                    tessellated_edges.insert(edge, indices);
                    adjacencies
                        .vertices
                        .extend(repeat(HashSet::new()).take(count - 1));
                }
            }

            // Tessellate triangle
            // All adjacent edges have been tessellated at this point.
            let p = points[triangle.0].dir();
            let pu = points[triangle.1].dir();
            let pv = points[triangle.2].dir();
            let start_index = points.len();

            // Generate points.
            for v in 1..count - 1 {
                let offset_v = (pv - p) * Scalar::new(v as f32 / count as f32);
                for u in 1..count - v {
                    let offset_u = (pu - p) * Scalar::new(u as f32 / count as f32);
                    let tessellated_point = p + offset_v + offset_u;
                    points.push(tessellated_point.point());
                    adjacencies.vertices.push(HashSet::new());
                }
            }

            // Generate triangles.
            let point_index = |u: usize, v: usize| {
                let edge_point = |edge: (usize, usize), i| {
                    let anti_edge = (edge.1, edge.0);
                    if let Some(points) = tessellated_edges.get(&edge) {
                        points[i - 1]
                    } else {
                        let anti_points = &tessellated_edges[&anti_edge];
                        anti_points[count - i - 1]
                    }
                };

                match (u, v) {
                    // Triangle vertices
                    (0, 0) => triangle.0,
                    (u, 0) if u == count => triangle.1,
                    (0, v) if v == count => triangle.2,

                    // Triangle edges
                    (u, 0) => edge_point((triangle.0, triangle.1), u),
                    (u, v) if u + v == count => edge_point((triangle.1, triangle.2), v),
                    (0, v) => edge_point((triangle.2, triangle.0), count - v),

                    // Triangle interior
                    (u, v) => {
                        let mut index = start_index;
                        index += u - 1;
                        index += (v - 1) * (count - 1) - ((v - 1) * ((v - 1) + 1) / 2);
                        index
                    }
                }
            };

            for v in 0..count {
                for u in 0..count - v {
                    let q = point_index(u, v);
                    let qu = point_index(u + 1, v);
                    let qv = point_index(u, v + 1);

                    triangles.push(Triangle(q, qu, qv));

                    if u < count - v - 1 {
                        let quv = point_index(u + 1, v + 1);
                        triangles.push(Triangle(quv, qv, qu));
                    }

                    adjacencies.connect(q, qu);
                    adjacencies.connect(qu, qv);
                    adjacencies.connect(qv, q);
                }
            }
        }

        assert_eq!(points.len(), adjacencies.vertices.len());
        (Shape { points, triangles }, adjacencies)
    }

    pub fn union(mut self, mut other: Shape) -> Shape {
        for triangle in other.triangles {
            self.triangles.push(triangle + self.points.len());
        }
        self.points.append(&mut other.points);
        self
    }
}

impl Add<usize> for Triangle {
    type Output = Triangle;

    fn add(self, rhs: usize) -> Triangle {
        Triangle(self.0 + rhs, self.1 + rhs, self.2 + rhs)
    }
}

impl Triangle {
    pub fn edges(self) -> [(usize, usize); 3] {
        [(self.0, self.1), (self.1, self.2), (self.2, self.0)]
    }

    pub fn midpoint(self, points: &[Point]) -> Point {
        points[self.0] + points[self.1] + points[self.2]
    }
}

pub fn anti_edge(edge: (usize, usize)) -> (usize, usize) {
    (edge.1, edge.0)
}

#[derive(Debug, Clone, Default)]
pub struct AdjacencyGraph {
    pub vertices: Vec<HashSet<usize>>,
}

impl AdjacencyGraph {
    #[track_caller]
    pub fn connect(&mut self, i: usize, j: usize) {
        self.vertices[i].insert(j);
        self.vertices[j].insert(i);
    }
}
