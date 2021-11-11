require daslib/media

require math_utils

struct Contact
    pos: float2
    normal: float2
    depth: float

struct RoadContact
    contact: Contact
    center: float2
    t: float

struct Spring
    from: float2
    to: float2

    dir: float2

    length: float
    curLength: float
    wishLength: float

let INVALID_CONTACT = [[Contact pos=float2(), normal=float2(), depth=-1.]]

def contact_circle_to_line(center: float2; radius: float; line_from, line_to: float2): Contact
    let from = line_from - center
    let to   = line_to - center

    var d = to - from
    let lenSq = length_sq(d)
    d /= sqrt(lenSq)

    let n = -perp(d)

    let r2 = radius * radius
    if length_sq(from) <= r2 && length_sq(to) <= r2
        let c = center + 0.5 * (from + to)
        return [[Contact pos=c, normal=n, depth=radius - length(center - c)]]

    let D = cross(from, to)
    let t = radius * radius * lenSq - D * D
    if t < 0.
        return [[Contact depth=-1.]]
    
    let s = sqrt(t)
    let sgnY = d.y < 0. ? -1. : 1.
    let c0 = center + float2(D * d.y + sgnY * d.x * s, -D * d.x + abs(d.y) * s) / lenSq
    let c1 = center + float2(D * d.y - sgnY * d.x * s, -D * d.x - abs(d.y) * s) / lenSq
    let c  = 0.5 * (c0 + c1)
    let prj = dot(c - line_from, d)
    if prj < 0. || prj * prj > lenSq
        return [[Contact depth=-1.]]

    return [[Contact pos=c, normal=n, depth=radius - length(center - c)]]
