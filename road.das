require daslib/media

require utils
require math_utils
require draw_utils

struct Road
    pos: float2
    speed: float

    offset: float
    scale: float
    step: float

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
    transform2d_push()
    transform2d_translate(r.pos)

    let roadColor = 0xF8F8FF
    let stepsCount = ceili(float(get_screen_width()) / (r.step * r.scale)) + 1
    draw_function(r.step, stepsCount, roadColor) <| $(x)
        return road_point(r, x)

    transform2d_pop()
