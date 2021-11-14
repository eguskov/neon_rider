require daslib/media

require common
require draw_utils
require math_utils
require particles
require car
require score

struct EnemySpawner
    seed: uint
    lastSpawn: int
    threshold: float
    rate: float

struct Enemy
    pos: float2
    vel: float2

    hp: float
    maxHp: float
    hitBox: float4

struct RombEnemy : Enemy
    size: float2
    initialSize: float2
    wishScale: float2

    maxVel: float

def RombEnemy()
    return [[RombEnemy hp=1.,
                       maxHp=1.,
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
    return [[FanEnemy hp=1., maxHp=1., hitBox=float4(-16., -16., 16., 16.)]]

struct DeathRayEnemy : Enemy
    timeToRay: float
    rayInterval: float
    wasVel: float2
    delay: float
    isDelayActive: bool

def DeathRayEnemy()
    return [[DeathRayEnemy hp=50., maxHp=50., hitBox=float4(-16., -32., 16., 0.)]]

var rombSpawner = [[EnemySpawner seed=2179u, threshold=0.5, rate=2.]]
var fanSpawner  = [[EnemySpawner seed=5531u, threshold=0.5, rate=1.]]

var fanEnemies: array<FanEnemy>
var rombEnemies: array<RombEnemy>
var deathRayEnemies: array<DeathRayEnemy>

/* ====[ Common ]==== */

def clear_enemies()
    fanEnemies |> clear()
    rombEnemies |> clear()
    deathRayEnemies |> clear()

def draw_enemies()
    for e in fanEnemies; { draw(e); }
    for e in rombEnemies; { draw(e); }
    for e in deathRayEnemies; { draw(e); }

def animate_enemies(dt, atTime: float)
    for e in fanEnemies; { animate(e, dt, atTime); }
    for e in rombEnemies; { animate(e, dt, atTime); }
    for e in deathRayEnemies; { animate(e, dt, atTime); }

def update_enemies(dt, atTime: float)
    for e in fanEnemies; { update(e, dt, atTime); }
    for e in rombEnemies; { update(e, dt, atTime); }
    for e in deathRayEnemies; { update(e, dt, atTime); }

def integrate_enemies(dt)
    fanEnemies |> integrate(dt)
    rombEnemies |> integrate(dt)
    deathRayEnemies |> integrate(dt)

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
    deathRayEnemies |> hit_enemies(p)

[generic]
def hit_car_by_enemies(var enemies; var car: Car)
    for e in enemies
        if e.hp > 0. && length_sq(e.pos - car.worldCenter) < (car.hitRadius * car.hitRadius) /* intercect_box(e.hitBox, car.hitBox) */
            e.hp = 0.
            car.hp -= 1.

def hit_car_by_enemies(var car: Car)
    fanEnemies |> hit_car_by_enemies(car)
    rombEnemies |> hit_car_by_enemies(car)
    
    for dr in deathRayEnemies
        if dr.isDelayActive && dr.delay < 1.2
            if length_sq(float2(dr.pos.x, car.worldCenter.y) - car.worldCenter) < (car.hitRadius * car.hitRadius)
                car.hp -= 1.

[generic]
def erase_dead_whit_fx(var enemies)
    var i = length(enemies)
    while --i >= 0
        if enemies[i].hp <= 0.
            explostion(enemies[i].pos)
            score += 10. * enemies[i].maxHp
            enemies |> erase(i)

def erase_dead_whit_fx()
    fanEnemies |> erase_dead_whit_fx()
    rombEnemies |> erase_dead_whit_fx()
    deathRayEnemies |> erase_dead_whit_fx()

def should_spawn(var spawner: EnemySpawner; atTime: float)
    let i = floori(spawner.rate * atTime)
    if i != spawner.lastSpawn && noise(i, spawner.seed) >= spawner.threshold
        spawner.lastSpawn = i
        return true
    return false

var dbg = true

var nextDeathRaySpawnAtTime = 0.
var deathRaySpawnInterval = 10.

def spawn_enemies(atTime: float)
    if should_spawn(rombSpawner, atTime)
        rombEnemies |> push(spawn(RombEnemy()))

    if should_spawn(fanSpawner, atTime)
        fanEnemies |> push(spawn(FanEnemy()))

    if length(deathRayEnemies) == 0 && atTime >= nextDeathRaySpawnAtTime
        nextDeathRaySpawnAtTime = atTime + deathRaySpawnInterval
        deathRayEnemies |> push(spawn(DeathRayEnemy()))
    elif length(deathRayEnemies) != 0
        nextDeathRaySpawnAtTime = atTime + deathRaySpawnInterval

    // if dbg
    //     dbg = false
    //     deathRayEnemies |> push(spawn(DeathRayEnemy()))

/* ====[ Romb ]==== */

def spawn(var romb: RombEnemy)
    let border = 128.
    let posX = rnd_range(border, float(get_screen_width()) - 2. * border)
    romb.pos = float2(posX, 0.f)
    romb.maxVel = rnd_range(140., 200.)
    return romb

def draw(romb: RombEnemy)
    let scale = 0.75
    let sz = romb.size * scale
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
    fan.maxVel = -rnd_range(120., 200.)
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

/* ====[ DeathRay ]==== */

def spawn(var dr: DeathRayEnemy)
    dr.pos = float2(128., 80.)
    dr.vel = float2(-120., 0.)
    dr.rayInterval = rnd_range(5., 10.)
    dr.timeToRay = dr.rayInterval 
    return dr

def draw(dr: DeathRayEnemy)
    let color = 0xCD5C5C

    transform2d_push()

    transform2d_translate(dr.pos)

    dotTextureLowGlow |> draw_segment(float2(-8., 0.), float2(-22., -16.), color)
    dotTextureLowGlow |> draw_segment(float2(-22., -16.), float2(-8., -32.), color)
    dotTextureLowGlow |> draw_segment(float2(-8., -32.), float2(8., -32.), color)
    dotTextureLowGlow |> draw_segment(float2(8., -32.), float2(22., -16.), color)
    dotTextureLowGlow |> draw_segment(float2(22., -16.), float2(8., 0.), color)
    dotTextureLowGlow |> draw_segment(float2(-8., 0.), float2(-12., -16.), color)
    dotTextureLowGlow |> draw_segment(float2(-12., -16.), float2(12., -16.), color)
    dotTextureLowGlow |> draw_segment(float2(12., -16.), float2(8., 0.), color)

    let sz = float2(solid.width)
    let innerPoints <- to_array([[auto[] float2(-8., 0.);
                                         float2(-22., -16.);
                                         float2(-12., -16.);
                                         float2(-8., -32.);
                                         float2(12., -16.);
                                         float2(8., -32.);
                                         float2(12., -16.);
                                         float2(22., -16.);
                                         float2(8., 0.)]])
    let innerUVs    <- to_array([[auto[] float2(0., sz.y);
                                         float2(0., 0.);
                                         float2(sz.x, sz.y); 
                                         float2(sz.x, 0.);
                                         float2(0., sz.y);
                                         float2(0., 0.);
                                         float2(sz.x, sz.y); 
                                         float2(sz.x, 0.);
                                         float2(0., sz.y);
                                         float2(0., 0.);
                                         float2(sz.x, sz.y); 
                                         float2(sz.x, 0.)]])

    let t = saturate(1. - (dr.hp / dr.maxHp))
    let innerColor = make_color(lerp(color_to_float3(0x0), color_to_float3(0xB22222), t) * car.alpha)

    solid |> draw_triangle_strip(innerPoints, innerUVs, innerColor)

    transform2d_pop()

def animate(var dr: DeathRayEnemy; dt, atTime: float)
    // fan.angle += fan.omega * dt
    pass

def update(var dr: DeathRayEnemy; dt, atTime: float)
    if dr.pos.x < 256.f
        dr.pos.x = 256.f
        dr.vel = -dr.vel
    if dr.pos.x > float(get_screen_width()) - 256.f
        dr.pos.x = float(get_screen_width()) - 256.f
        dr.vel = -dr.vel

    if dr.isDelayActive
        dr.delay -= dt
        if dr.delay <= 0.
            dr.isDelayActive = false
            dr.vel = dr.wasVel

    dr.timeToRay -= dt

    if dr.timeToRay <= 0.
        dr.timeToRay = dr.rayInterval
        dr.wasVel = dr.vel
        dr.vel = float2()
        dr.isDelayActive = true
        dr.delay = 2.
        beam(dr.pos, 2.)
