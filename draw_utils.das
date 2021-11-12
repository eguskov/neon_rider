require daslib/media

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

def draw_arc(img: ImageHandle; center: float2; radius: float; from_angle, to_angle: float; color: uint)
    let sz = float(img.width)
    let offset = max(sz - radius, 0.0)
    var coords: array<float2>
    var uv: array<float2>

    let angleStep = PI * 2.0 / 32.0
    let toRad = PI / 180.
    let startRange = floori(from_angle * toRad / angleStep)
    let endRange   = ceili(to_angle * toRad / angleStep) + 1

    let count = endRange - startRange
    coords |> resize(count * 2)
    uv |> resize(count * 2)

    for i in range(startRange, endRange)
        let j = i - startRange
        let angle = float(i) * angleStep
        let dir = float2(cos(angle), sin(angle))
        coords[j * 2] = center + dir * (radius - sz + offset)
        coords[j * 2 + 1] = center + dir * (radius + sz)
        uv[j * 2] = float2(sz * 0.5, offset * 0.5)
        uv[j * 2 + 1] = float2(sz * 0.5, sz)

    img |> draw_triangle_strip(coords, uv, color)

let dotTexture = create_segment_texture(0.4 /* glow_intencity */)
let dotTextureNoGlow = create_segment_texture(0.01 /* glow_intencity */)
let dotTextureLowGlow = create_segment_texture(0.2 /* glow_intencity */)
let dotTextureHighGlow = create_segment_texture(0.8 /* glow_intencity */)

let solid = create_managed_image(1, 1, to_array([[auto[] make_color(1., 0.)]]), true, false)
