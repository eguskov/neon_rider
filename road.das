require daslib/media

require utils

struct Road
    pos: float2
    speed: float

    offset: float
    scale: float
    step: float

def hermit_interp(from, to, m0, m1, t: float)
    let t2 = t * t
    let t3 = t2 * t
    return (2. * t3 - 3. * t2 + 1.) * from + (t3 - 2. * t2 + t) * m0 + (-2. * t3 + 3. * t2) * to + (t3 - t2) * m1

def road_fn(x: float)
    let seed = 17u
    let cur  = noise(floori(x), seed)
    let next = noise(ceili(x), seed)
    let prev = noise(floori(x) - 1, seed)
    let t = 1. - ceil(x) + x

    let m0 = cur - prev
    let m1 = next - cur
    return hermit_interp(float(cur), float(next), m0, m1, t)

def road_point(r: Road; x: float)
    return float2(x, road_fn(x + r.offset)) * r.scale

def road_point_world(r: Road; x: float)
    return r.pos + float2(x, road_fn(x + r.offset)) * r.scale
