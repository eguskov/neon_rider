require daslib/media

require common
require draw_utils
require math_utils

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

var emitters: array<Emitter>
var particles: array<Particle>

def emit(emitter: Emitter)
    var p = [[Particle]]

    let sz = float2(dotTexture.width)

    let count = rnd_range(emitter.countRange)
    for i in range(count)
        let ap = rnd_range(emitter.angleRange)
        let av = rnd_range(emitter.velAngleRange)
        p.pos = emitter.pos - sz + float2(cos(ap), sin(ap)) * rnd_range(emitter.radiusRange) + rnd_range(emitter.posRange)
        p.vel = float2(cos(av), sin(av)) * rnd_range(emitter.velRange)
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
    var e <- Emitter()
    e.colorRange    = [[auto[] color_to_float3(0x4169E1); color_to_float3(0x4169E1)]]
    e.pos           = pos
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

def update_particles(dt: float)
    for e in emitters
        e |> emit()
        e.ttl -= dt

    for p in particles
        let t = 1. - saturate((p.maxTtl - p.ttl) / p.maxTtl)
        p.ttl -= dt
        if !p.isAttractedTo
            p.pos += p.vel * dt
        else
            p.pos += length(p.vel) * normalize(p.attractTo - p.pos) * dt
        p.alpha = lerp(p.startAlpha, p.wishAlpha, t)

    emitters |> erase_by_ttl()
    particles |> erase_by_ttl()

def draw_particles()
    for p in particles
        let c = p.color * p.alpha
        let s = float2(dotTexture.width) * p.scale
        dotTexture |> draw_image(p.pos.x, p.pos.y, make_color(c.x, c.y, c.z, 0.), s)
