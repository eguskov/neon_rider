require daslib/media

require common
require draw_utils
require math_utils
require road

struct Particle
    pos: float2
    vel: float2
    alpha: float
    scale: float
    color: float3

    startAlpha: float
    wishAlpha: float

    ttl: float
    maxTtl: float

    isAttractedTo: bool
    attractTo: float2

struct Emitter
    pos: float2
    dir: float2
    vel: float2
    angle: float
    omega: float

    ttl: float

    colorRange: float3[2]

    ttlRange: float2

    radiusRange: float2
    angleRange: float2

    posRange: float4

    velRange: float2
    velAngleRange: float2

    alphaRange: float2
    wishAlphaRange: float2
   
    scaleRange: float2

    countRange: int2

    isAttractedTo: bool

def Emitter()
    return <- [[Emitter alphaRange=float2(1.),
                        colorRange=[[auto[] float3(1.); float3(1.)]],
                        angleRange=float2(0., 2. * PI),
                        scaleRange=float2(1.),
                        countRange=int2(1)
              ]]

struct Beam
    pos: float2
    tail: float2
    colorRange: float3[2]
    color: float3
    length: float
    lengthVel: float
    wishLength: float
    alpha: float
    scale: float
    ttl: float
    phase: float
    phaseTail: float
    count: int
    tailCount: int
    tailHeight: float
    delay: float
    lastSmallFireAtTime: float
    shouldDrawTail: bool

var emitters: array<Emitter>
var particles: array<Particle>
var beams: array<Beam>

def emit(emitter: Emitter)
    var p = [[Particle]]

    let sz = float2(dotTexture.width)

    let count = rnd_range(emitter.countRange)
    for i in range(count)
        let ap = rnd_range(emitter.angleRange)
        let av = rnd_range(emitter.velAngleRange)
        p.pos = emitter.pos - sz + float2(cos(ap), sin(ap)) * rnd_range(emitter.radiusRange) + rnd_range(emitter.posRange)
        p.vel = emitter.vel + float2(cos(av), sin(av)) * rnd_range(emitter.velRange)
        p.ttl = rnd_range(emitter.ttlRange)
        p.maxTtl = p.ttl
        p.startAlpha = rnd_range(emitter.alphaRange)
        p.wishAlpha  = rnd_range(emitter.wishAlphaRange)
        p.color = rnd_range(emitter.colorRange)
        p.scale = rnd_range(emitter.scaleRange)

        p.isAttractedTo = emitter.isAttractedTo
        if p.isAttractedTo
            p.attractTo = emitter.pos - float2(dotTexture.width)

        particles |> push(p)

def explostion(pos: float2)
    var e <- Emitter()
    e.colorRange    = [[auto[] color_to_float3(0xDC143C); color_to_float3(0xFFA500)]]
    e.pos           = pos
    e.ttlRange      = float2(.25, .5)
    e.velRange      = float2(16., 32.) * 8.
    e.alphaRange    = float2(1.)
    e.radiusRange   = float2(8.)
    e.velAngleRange = float2(0., 2. * PI)
    e.scaleRange    = float2(2.)
    e.countRange    = int2(32, 64)
    e.ttl           = .1
    emitters |> push(e)

def warp(pos: float2; ttl: float)
    let sz = float2(dotTexture.width)
    var e <- Emitter()
    e.colorRange    = [[auto[] color_to_float3(0x4169E1); color_to_float3(0x4169E1)]]
    e.pos           = pos - sz
    e.ttlRange      = float2(.25, .5)
    e.velRange      = float2(16., 32.) * 8.
    e.alphaRange    = float2(0.7)
    e.radiusRange   = float2(64.)
    e.velAngleRange = float2(0.)
    e.scaleRange    = float2(2.)
    e.countRange    = int2(16, 32)
    e.angle = 0.
    e.omega = 0.
    e.ttl   = ttl
    e.isAttractedTo = true
    emitters |> push(e)

def wall_of_file(pos: float2; dir: float)
    let hh = 0.5 * float(get_screen_height())
    var e <- Emitter()
    e.colorRange    = [[auto[] color_to_float3(0x8B0000); color_to_float3(0x8B0000)]]
    e.pos           = pos
    e.ttlRange      = float2(1.25, .5)
    e.posRange      = float4(0.f, 0.f, -hh, hh)
    e.velRange      = float2(16., 32.) * dir
    e.alphaRange    = float2(1.)
    e.radiusRange   = float2(8.)
    e.velAngleRange = float2(0., 2. * PI)
    e.scaleRange    = float2(2.5)
    e.countRange    = int2(8, 8)
    e.ttl           = 1e6
    emitters |> push(e)

def small_fire(pos: float2; vel: float2)
    var e <- Emitter()
    e.colorRange    = [[auto[] color_to_float3(0xDC143C); color_to_float3(0xFFA500)]]
    e.pos           = pos
    e.vel           = vel
    e.ttlRange      = float2(.25, .5)
    e.velRange      = float2(16., 32.) * 3.
    e.alphaRange    = float2(1.)
    e.radiusRange   = float2(8.)
    e.velAngleRange = float2(-PI, -0.5 * PI)
    e.scaleRange    = float2(1.)
    e.countRange    = int2(4, 8)
    e.ttl           = 1e6
    emitters |> push(e)

def beam(pos: float2; ttl: float)
    var b = [[Beam]]
    b.pos = pos/*  - float2(float(dotTexture.width)) */
    b.colorRange = [[auto[] color_to_float3(0x4169E1); color_to_float3(0x1E90FF)]]
    b.ttl = ttl
    b.alpha = 1.
    b.scale = 3.
    b.wishLength = 700.
    b.count = 128
    b.tailHeight = 64.
    b.tailCount = 128
    b.delay = 0.3
    b.lengthVel = 100.
    beams |> push(b)

    warp(pos + float2(float(dotTexture.width)), ttl - 0.5)

def update_particles(dt, atTime: float)
    for e in emitters
        e |> emit()
        e.ttl -= dt
        e.pos += e.vel * dt

    for p in particles
        let t = 1. - saturate((p.maxTtl - p.ttl) / p.maxTtl)
        p.ttl -= dt
        if !p.isAttractedTo
            p.pos += p.vel * dt
        else
            p.pos += length(p.vel) * normalize(p.attractTo - p.pos) * dt
        p.alpha = lerp(p.startAlpha, p.wishAlpha, t)

    for b in beams
        b.ttl -= dt
        b.delay -= dt
        b.phase -= 64. * dt
        b.phaseTail -= 8. * dt

        if b.delay <= 0.
            b.lengthVel += 3500. * dt
            b.length = min(b.length + b.lengthVel * dt, b.wishLength)

        if b.ttl < 0.5
            b.pos.y += 1000. * dt
        
        let t = (sin(20. * atTime) + 1.) * 0.5
        b.color = lerp(b.colorRange[0], b.colorRange[1], t)

        b.tail = b.pos + float2(0., b.length)

        let roadPos = road |> road_point_wpos(b.pos.x)

        b.tail.y = min(b.tail.y, roadPos.y)
        b.length = b.tail.y - b.pos.y

        if abs(roadPos.y - b.tail.y) < 1.
            b.shouldDrawTail = true

            road |> add_road_patch(b.pos.x, 3.f * dt)

            let roadPosAfterPatch = road |> road_point_wpos(b.pos.x)
            if atTime - b.lastSmallFireAtTime > 0.02
                b.lastSmallFireAtTime = atTime
                small_fire(roadPosAfterPatch + float2(dotTexture.width), float2(-road.speed * road.scale, 0.f))

    emitters |> erase_by_offscreen()
    emitters |> erase_by_ttl()
    particles |> erase_by_ttl()
    beams |> erase_by_ttl()

def draw_particles()
    for p in particles
        let c = p.color * p.alpha
        let s = float2(dotTexture.width) * p.scale
        dotTexture |> draw_image(p.pos.x, p.pos.y, make_color(c.x, c.y, c.z, 0.), s)

    let sz = 0.5 * float2(dotTexture.width)
    for b in beams
        if b.delay > 0.
            continue

        let c = b.color * b.alpha
        dotTexture |> draw_segment(b.pos, b.tail, make_color(c.x, c.y, c.z, 0.), b.scale)

        let step = b.length / float(b.count)
        for i in range(b.count)
            let p = b.pos + float2(8.*sin(float(i) + b.phase), float(i) * step) - sz
            dotTexture |> draw_image(p.x, p.y, make_color(c.x, c.y, c.z, 0.))

        if b.shouldDrawTail
            let step1 = b.tailHeight / float(b.tailCount)
            for i in range(b.tailCount)
                let s = 0. * sin(b.phaseTail + 0.5 * float(i))
                let t = float(i) / float(b.tailCount)
                let a = lerp(0., 32., t) + s + rnd_range(0., 16.)
                let p = b.tail + float2(a * sin(b.phaseTail - float(i)), -float(i) * step1) - sz
                let c1 = c * saturate(1. - float(i)/float(b.tailCount))
                dotTexture |> draw_image(p.x, p.y, make_color(c1.x, c1.y, c1.z, 0.))
