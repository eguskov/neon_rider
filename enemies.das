require daslib/media

require common
require draw_utils
require math_utils
require particles
require car

struct EnemySpawner
    seed: uint
    lastSpawn: int
    threshold: float
    rate: float

struct Enemy
    pos: float2
    vel: float2

    hp: float
    hitBox: float4

struct RombEnemy : Enemy
    size: float2
    initialSize: float2
    wishScale: float2

    maxVel: float

def RombEnemy()
    return [[RombEnemy hp=1.,
                       hitBox=float4(-16., -16., 16., 16.),
                       size=float2(32.),
                       initialSize=float2(32.),
                       wishScale=float2(.8, .8),
                       maxVel=64.
           ]]

struct FanEnemy : Enemy
    angle: float
    omega: float
    height: float
    amplitude: float
    freq: float
    phase: float
    maxVel: float

def FanEnemy()
    return [[FanEnemy hp=1., hitBox=float4(-16., -16., 16., 16.)]]

var rombSpawner = [[EnemySpawner seed=2179u, threshold=0.5, rate=2.]]
var fanSpawner  = [[EnemySpawner seed=5531u, threshold=0.5, rate=1.]]

var rombEnemies: array<RombEnemy>
var fanEnemies: array<FanEnemy>

/* ====[ Common ]==== */

def draw_enemies()
    for e in fanEnemies; { draw(e); }
    for e in rombEnemies; { draw(e); }

def animate_enemies(dt, atTime: float)
    for e in fanEnemies; { animate(e, dt, atTime); }
    for e in rombEnemies; { animate(e, dt, atTime); }

def update_enemies(dt, atTime: float)
    for e in fanEnemies; { update(e, dt, atTime); }
    for e in rombEnemies; { update(e, dt, atTime); }

def integrate_enemies(dt)
    fanEnemies |> integrate(dt)
    rombEnemies |> integrate(dt)

[generic]
def hit_enemies(var enemies; var p: Projectile)
    if p.ttl <= 0.
        return

    for e in enemies
        if e.hp > 0. && in_box(e.hitBox, p.pos - e.pos)
            e.hp -= p.damage
            p.ttl -= 1.

def hit_enemies(var p: Projectile)
    fanEnemies |> hit_enemies(p)
    rombEnemies |> hit_enemies(p)

[generic]
def erase_dead_whit_fx(var enemies)
    var i = length(enemies)
    while --i >= 0
        if enemies[i].hp <= 0.
            explostion(enemies[i].pos)
            enemies |> erase(i)

def erase_dead_whit_fx()
    fanEnemies |> erase_dead_whit_fx()
    rombEnemies |> erase_dead_whit_fx()

def should_spawn(var spawner: EnemySpawner; atTime: float)
    let i = floori(spawner.rate * atTime)
    if i != spawner.lastSpawn && noise(i, spawner.seed) >= spawner.threshold
        spawner.lastSpawn = i
        return true
    return false

var dbg = false

def spawn_enemies(atTime: float)
    if should_spawn(rombSpawner, atTime)
        rombEnemies |> push(spawn(RombEnemy()))

    if should_spawn(fanSpawner, atTime)
        fanEnemies |> push(spawn(FanEnemy()))

    if dbg
        dbg = false
        fanEnemies |> push(spawn(FanEnemy()))

/* ====[ Romb ]==== */

def spawn(var romb: RombEnemy)
    let border = 128.
    let posX = rnd_range(border, float(get_screen_width()) - 2. * border)
    romb.pos = float2(posX, 0.f)
    romb.maxVel = rnd_range(64., 100.)
    return romb

def draw(romb: RombEnemy)
    let sz = romb.size
    let p  = romb.pos
    let color = 0xFFFF00FF
    dotTexture |> draw_segment(p - float2(sz.x, 0.), p - float2(0.f, sz.y), color)
    dotTexture |> draw_segment(p - float2(0., sz.y), p + float2(sz.x, 0.), color)
    dotTexture |> draw_segment(p + float2(sz.x, 0.), p + float2(0.f, sz.y), color)
    dotTexture |> draw_segment(p + float2(0.f, sz.y), p - float2(sz.x, 0.), color)

def animate(var romb: RombEnemy; dt, atTime: float)
    let wishSize = romb.initialSize * romb.wishScale
    let d = wishSize - romb.initialSize
    let freq = 6.
    romb.size = romb.initialSize + d * float2(sin(freq * atTime), sin(freq * atTime + 1. * PI))

def update(var romb: RombEnemy; dt, atTime: float)
    let dir = normalize(car.pos - romb.pos)
    romb.vel = romb.maxVel * dir

/* ====[ Fan ]==== */

def spawn(var fan: FanEnemy)
    let border = 64.
    let hh = 0.55 * float(get_screen_height())
    let posY = rnd_range(hh - border, hh + border)
    fan.pos = float2(float(get_screen_width()), posY)
    fan.maxVel = -rnd_range(64., 100.)
    fan.omega  = -rnd_range(1., 2.)
    fan.height = posY
    fan.amplitude = rnd_range(32., 64.)
    fan.freq = rnd_range(2., 3.)
    fan.phase = rnd_range(0., 2. * PI)
    return fan

def draw(fan: FanEnemy)
    let color = 0x7FFFD4

    transform2d_push()

    transform2d_translate(fan.pos)
    transform2d_rotate(fan.angle)

    let p = float2()

    dotTextureLowGlow |> draw_segment(p, p + float2(16., 0.), color)
    dotTextureLowGlow |> draw_segment(p + float2(16., 0.), p + float2(16., 16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(16., 16.), p, color)

    dotTextureLowGlow |> draw_segment(p, p + float2(0., 16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(0., 16.), p + float2(-16., 16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(-16., 16.), p, color)

    dotTextureLowGlow |> draw_segment(p, p + float2(-16., 0.), color)
    dotTextureLowGlow |> draw_segment(p + float2(-16., 0.), p + float2(-16., -16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(-16., -16.), p, color)

    dotTextureLowGlow |> draw_segment(p, p + float2(0., -16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(0., -16.), p + float2(16., -16.), color)
    dotTextureLowGlow |> draw_segment(p + float2(16., -16.), p, color)

    transform2d_pop()

def animate(var fan: FanEnemy; dt, atTime: float)
    fan.angle += fan.omega * dt

def update(var fan: FanEnemy; dt, atTime: float)
    fan.vel = float2(fan.maxVel, 0.)
    fan.pos.y = fan.height + fan.amplitude * sin(fan.freq * atTime + fan.phase)
