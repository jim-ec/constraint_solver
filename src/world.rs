use cgmath::{num_traits::Zero, InnerSpace, Quaternion, Rad, Rotation3, Vector3};

use crate::{collision, debug, rigid, solver};

#[derive(Clone, Copy)]
pub struct World {
    a: rigid::Rigid,
    b: rigid::Rigid,
}

impl World {
    pub fn new() -> World {
        let mut a = rigid::Rigid::new(1.0);
        a.external_force.z = -5.0;
        a.velocity.z = -0.2;
        a.angular_velocity.z = 1.0;
        a.frame.position.z = 5.0;
        a.frame.quaternion =
            Quaternion::from_axis_angle(Vector3::new(1.0, 0.5, 0.2).normalize(), Rad(1.0));
        a = a.forget_past();

        let mut b = rigid::Rigid::new(1.0);
        b.frame.position.z = 2.1;
        b = b.forget_past();

        World { a, b }
    }

    pub fn integrate(&mut self, dt: f64, debug_lines: &mut debug::DebugLines) {
        solver::step(&mut self.a, dt, 25);

        const DEBUG_GJK: [f32; 3] = [1.0, 0.0, 1.0];

        let mut points = vec![];
        for point_a in collision::CUBE_VERTICES {
            let point_a = self.a.frame.act(point_a);
            for point_b in collision::CUBE_VERTICES {
                let point_b = self.b.frame.act(point_b);
                let minkowski_difference = point_a - point_b;
                debug_lines.point(minkowski_difference, [0.0, 1.0, 0.0]);
                points.push(minkowski_difference);
            }
        }
        let convex_hull = convex(&points);
        for c in &convex_hull {
            debug_lines.point(points[c.0], DEBUG_GJK);
            debug_lines.point(points[c.1], DEBUG_GJK);
            debug_lines.point(points[c.2], DEBUG_GJK);
        }

        if let Some((f, _)) = convex_hull
            .iter()
            .filter_map(|&f| {
                let a = points[f.0];
                let b = points[f.1];
                let c = points[f.2];
                let n = (b - a).cross(c - a);
                let distance = n.normalize().dot(a);

                let ab = b - a;
                let bc = c - b;
                let ca = a - c;

                let ao = -a;
                let bo = -b;
                let co = -c;

                let within_ab = ao.dot(ab) >= 0.0 && bo.dot(-ab) >= 0.0;
                let within_bc = bo.dot(bc) >= 0.0 && co.dot(-bc) >= 0.0;
                let within_ca = co.dot(ca) >= 0.0 && ao.dot(-ca) >= 0.0;

                let within_abc = within_ab && within_bc && within_ca;

                if within_abc {
                    Some((f, distance.abs()))
                } else {
                    None
                }
            })
            .min_by(|(_, d0), (_, d1)| d0.total_cmp(d1))
        {
            debug_lines.line(
                vec![points[f.0], points[f.1], points[f.2], points[f.0]],
                [1.0, 0.0, 0.0],
            );
        }

        if let Some(tetra) = self.a.gjk(&self.b) {
            debug_lines.line(vec![tetra.0, tetra.1], DEBUG_GJK);
            debug_lines.line(vec![tetra.0, tetra.2], DEBUG_GJK);
            debug_lines.line(vec![tetra.0, tetra.3], DEBUG_GJK);
            debug_lines.line(vec![tetra.1, tetra.2], DEBUG_GJK);
            debug_lines.line(vec![tetra.1, tetra.3], DEBUG_GJK);
            debug_lines.line(vec![tetra.2, tetra.3], DEBUG_GJK);
        }

        if let Some(collision) = self.a.epa(&self.b) {
            self.a.color = [1.0, 0.0, 0.0];
            self.b.color = [1.0, 0.0, 0.0];
            debug_lines.line(
                vec![Vector3::zero(), collision.depth * collision.normal],
                [1.0, 0.0, 0.0],
            );
        } else {
            self.a.color = rigid::DEFAULT_COLOR;
            self.b.color = rigid::DEFAULT_COLOR;
        }
    }

    pub fn rigids(&self) -> Vec<&rigid::Rigid> {
        vec![&self.a, &self.b]
    }
}

#[allow(clippy::needless_range_loop)]
fn convex(m: &[Vector3<f64>]) -> Vec<(usize, usize, usize)> {
    let mut convex_hull = vec![];

    for i0 in 0..m.len() {
        for i1 in i0 + 1..m.len() {
            for i2 in i1 + 1..m.len() {
                let v0 = m[i0];
                let v1 = m[i1];
                let v2 = m[i2];

                let normal = (v1 - v0).cross(v2 - v0);
                if normal.magnitude2() == 0.0 {
                    continue;
                }

                let mut any_in_normal_direction = false;
                let mut any_in_anti_normal_direction = false;

                for i3 in 0..m.len() {
                    if [i0, i1, i2].contains(&i3) {
                        continue;
                    }
                    let v = m[i3];

                    let in_normal = collision::same_direction(normal, v - v0);
                    let in_anti_normal = collision::same_direction(-normal, v - v0);

                    any_in_normal_direction |= in_normal;
                    any_in_anti_normal_direction |= in_anti_normal;

                    if any_in_normal_direction && any_in_anti_normal_direction {
                        break;
                    }
                }

                if any_in_normal_direction && !any_in_anti_normal_direction {
                    convex_hull.push((i0, i1, i2));
                }
                if !any_in_normal_direction && any_in_anti_normal_direction {
                    convex_hull.push((i0, i2, i1));
                }
            }
        }
    }

    convex_hull
}
