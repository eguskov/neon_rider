require daslib/media

require common
require math_utils
require draw_utils

struct Road
    pos: float2
    speed: float

    offset: float
    scale: float
    step: float

struct RoadPatch
    i: int
    dy: float

var road_patches: table<int; RoadPatch>

def find_road_patch(r: Road; x: float)
    return r |> road_point_index(x) |> find_road_patch_by_index()

def find_road_patch_by_index(i: int): RoadPatch?
    var res: RoadPatch?
    road_patches |> find_if_exists(i) <| $(p: RoadPatch?)
        res = p
    return res

def add_road_patch(r: Road; x, dy: float)
    // let rx = (float(road_point_index(r, x)) * r.step + r.offset) * r.scale
    let rx = ceili((x / r.scale) + r.offset)
    var patch = find_road_patch_by_index(rx)
    if patch != null
        patch.dy += dy
    else
        // let i = road_point_index(r, rx)
        road_patches[rx] = [[RoadPatch i=rx, dy=dy]]

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

def road_with_patch_fn(pos: int; seed: uint)
    let dy = find_road_patch_by_index(pos)?.dy ?? 0.
    return noise(pos, seed) + dy

def road_fn(x: float)
    let seed = 17u
    let i = floori(x)
    let cur  = road_with_patch_fn(floori(x), seed)
    let next = road_with_patch_fn(ceili(x), seed)
    let prev = road_with_patch_fn(floori(x) - 1, seed)
    let t = 1. - ceil(x) + x

    let m0 = cur - prev
    let m1 = next - cur
    return hermit_interp(float(cur), float(next), m0, m1, t)

def road_point(r: Road; x: float)
    return float2(x, road_fn(x + r.offset)) * r.scale

def road_point_world(r: Road; x: float)
    return r.pos + float2(x, road_fn(x + r.offset)) * r.scale

def road_point_index(r: Road; x: float)
    return ceili(x / (r.step * r.scale))

def road_point_wpos(r: Road; x: float)
    return r |> road_point_world(ceil(x / (r.step * r.scale)) * r.step)

def road_point_wpos_by_index(r: Road; i: int)
    return r |> road_point_world(float(i) * r.step)

def find_contact_with_road(road: Road; pos: float2; radius: float)
    let minPos = pos - float2(radius)
    let maxPos = pos + float2(radius)

    let rangeStart = ceili(minPos.x / (road.step * road.scale))
    let rangeCount = ceili((maxPos.x - minPos.x) / (road.step * road.scale))

    var from = road |> road_point_world(float(rangeStart - 1) * road.step)
    for i in range(rangeStart, rangeStart + rangeCount)
        let to = road |> road_point_world(float(i) * road.step)

        let c = contact_circle_to_line(pos, radius, from, to)
        if c.depth >= 0.
            return c

        from = to

    return INVALID_CONTACT

def find_contact_with_road(road: Road;from, to: float2; radius: float; step: float)
    let velStep = step * normalize(to - from)
    let maxDist = length(to - from)
    var d = maxDist

    var contact := INVALID_CONTACT
    var center = to

    var p = from
    while d >= 0.
        let c = find_contact_with_road(road, p, radius)
        if c.depth >= 0.
            contact := c
            center = p
            break

        p += velStep
        d -= step

    let t = maxDist >= 1.e-5 ? length(center - from) / maxDist : 1.

    return [[RoadContact contact=contact, center=center, t=t]]

def draw_function(step: float; steps_count: int; color: uint; fn: block<(x: float):float2>)
    let h  = float(dotTextureHighGlow.height)
    let hh = 0.5 * h

    var from = fn |> invoke(0.)
   
    let firstTo = fn |> invoke(step)
    let firstD  = normalize(firstTo - from)
    let firstN  = float2(-firstD.y, firstD.x)

    var prevTop    = from - firstN * hh
    var prevBottom = from + firstN * hh

    for i in range(1, steps_count)
        let x  = float(i) * step
        let to = fn |> invoke(x)

        let d = normalize(to - from)
        let n = float2(-d.y, d.x)

        let rt = to - n * hh
        let rb = to + n * hh

        dotTexture |> draw_segment_inner(prevTop, rt, prevBottom, rb, color)

        prevBottom = rb
        prevTop    = rt

        from = to

def draw(r: Road)
    // let msg = length(road_patches) > 0 ? "{road_patches[0].i}" : ""
    // set_font_size(16)
    // text_out(10, 10, msg, 0xFFFFFFFF)

    transform2d_push()
    transform2d_translate(r.pos)

    let roadColor = 0xF8F8FF
    let stepsCount = ceili(float(get_screen_width()) / (r.step * r.scale)) + 1
    draw_function(r.step, stepsCount, roadColor) <| $(x)
        return road_point(r, x)

    transform2d_pop()

def update(var r: Road; dt: float)
    var keys: array<int>
    for rp in values(road_patches)
        if (float(rp.i) - r.offset) * r.scale < -256.
            keys |> push(rp.i)
    for k in keys
        road_patches |> erase(k)

var road: Road
