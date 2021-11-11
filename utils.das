require daslib/media

struct Contact
    pos: float2
    normal: float2
    depth: float

struct RoadContact
    contact: Contact
    center: float2
    t: float

struct Spring
    stiffness: float
    length: float

    from: float2
    to: float2

    dir: float2

    vel: float2

    curLength: float
    wishLength: float

let INVALID_CONTACT = [[Contact pos=float2(), normal=float2(), depth=-1.]]

def cross(a, b: float2)
    return a.x * b.y - a.y * b.x

def proj(a, b: float2)
    return normalize(b) * dot(a, b)

def perp(a, b: float2)
    return a - proj(a, b)

def perp(a: float2)
    return float2(-a.y, a.x)

def noise(pos: int; seed: uint)
    let maxrndfloat = 16777215.0 // float can only hold 23-bits integers without data loss
    let maxrndfloatmask = 16777215u // (1<24)-1
    return float(uint_noise_1D(pos, seed) & maxrndfloatmask) / maxrndfloat // [0,1]

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

def color_to_float3(c: uint)
    let r = (c >> 16u) & 0xFF
    let g = (c >>  8u) & 0xFF
    let b = (c >>  0u) & 0xFF
    return float3(float(r)/255., float(g)/255., float(b)/255.)

def create_segment_texture(glow_intencity: float): ImageHandle
    let size = 21
    var img = create_managed_image(size, size, true /* smooth */, false /* mips */)
    for y in range(size)
        let dy = float(y - size / 2) / float(size / 2)
        for x in range(size)
            let dx = float(x - size / 2) / float(size / 2)
            let len = sqrt(dx * dx + dy * dy)
            let invLen = 1.0 - saturate(len)
            let glow = invLen * invLen * glow_intencity
            let line = sqr(1.0 - saturate(len * 8.0))
            img |> set_pixel(x, y, make_color(max(line, glow), line))

    return img

def draw_segment(img: ImageHandle; from, to: float2; color: uint)
    let sz = float(img.width)
    let d = normalize(to - from) * sz * 0.9
    let n = float2(-d.y, d.x) * 0.9

    let coords <- to_array([[auto[]
            from - d - n;
            from - d + n;
            from - n;
            from + n;
            to - n;
            to + n;
            to + d - n;
            to + d + n
        ]])

    let uvs <- to_array([[auto[]
            float2(0.0, 0.0);
            float2(0.0, sz);
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz);
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz);
            float2(sz, 0.0);
            float2(sz, sz)
        ]])

    img |> draw_triangle_strip(coords, uvs, color)

def draw_segment_inner(img: ImageHandle; from, to: float2; color: uint)
    let sz = float(img.width)
    let d = normalize(to - from) * sz * 0.9
    let n = float2(-d.y, d.x) * 0.9

    let coords <- to_array([[auto[]
            from - n;
            from + n;
            to - n;
            to + n
        ]])

    let uvs <- to_array([[auto[]
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz);
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz)
        ]])

    img |> draw_triangle_strip(coords, uvs, color)

def draw_segment_inner(img: ImageHandle; lt, rt, lb, rb: float2; color: uint)
    let sz = float(img.width)
    let coords <- to_array([[auto[] lb; lt; rb; rt]])
    let uvs <- to_array([[auto[]
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz);
            float2(sz * 0.5, 0.0);
            float2(sz * 0.5, sz)
        ]])

    img |> draw_triangle_strip(coords, uvs, color)

def draw_circle(img: ImageHandle; center: float2; radius: float; color: uint)
    let sz = float(img.width)
    let offset = max(sz - radius, 0.0)
    var coords: array<float2>
    var uv: array<float2>

    coords |> resize((32 + 1) * 2)
    uv |> resize((32 + 1) * 2)

    for i in range(32)
        let angle = float(i) * PI * 2.0 / 32.0
        let dir = float2(cos(angle), sin(angle))
        coords[i * 2] = center + dir * (radius - sz + offset)
        coords[i * 2 + 1] = center + dir * (radius + sz)
        uv[i * 2] = float2(sz * 0.5, offset * 0.5)
        uv[i * 2 + 1] = float2(sz * 0.5, sz)

    coords[32 * 2] = coords[0]
    coords[32 * 2 + 1] = coords[1]
    uv[32 * 2] = uv[0]
    uv[32 * 2 + 1] = uv[1]

    img |> draw_triangle_strip(coords, uv, color)