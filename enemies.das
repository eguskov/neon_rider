require daslib/media

require common
require draw_utils
require math_utils
require particles
require car

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
                       size=float2(32.),
                       initialSize=float2(32.),
                       wishScale=float2(.8, .8),
                       hitBox=float4(-16., -16., 16., 16.),
                       maxVel=64.
           ]]

struct QuadEnemy : Enemy {}

var rombEnemies: array<RombEnemy>
var quadEnemies: array<QuadEnemy>

struct EnemySpawner
    seed: uint
    lastSpawn: int
    threshold: float
    rate: float

def draw_enemies()
    for e in quadEnemies; { draw(e); }
    for e in rombEnemies; { draw(e); }

def animate_enemies(dt, atTime: float)
    for e in quadEnemies; { animate(e, dt, atTime); }
    for e in rombEnemies; { animate(e, dt, atTime); }

def update_enemies(dt, atTime: float)
    for e in quadEnemies; { update(e, dt, atTime); }
    for e in rombEnemies; { update(e, dt, atTime); }

def integrate_enemies(dt)
    quadEnemies |> integrate(dt)
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
    quadEnemies |> hit_enemies(p)
    rombEnemies |> hit_enemies(p)

[generic]
def erase_dead_whit_fx(var enemies)
    var i = length(enemies)
    while --i >= 0
        if enemies[i].hp <= 0.
            explostion(enemies[i].pos)
            enemies |> erase(i)

def erase_dead_whit_fx()
    quadEnemies |> erase_dead_whit_fx()
    rombEnemies |> erase_dead_whit_fx()

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

var rombSpawner = [[EnemySpawner seed=2179u, threshold=0.5, rate=2.]]

def spawn(var romb: RombEnemy)
    let border = 128.
    let posX = rnd_range(float2(border, float(get_screen_width()) - 2. * border))
    romb.pos = float2(posX, 0.f)
    romb.maxVel = rnd_range(64., 100.)
    return romb

def should_spawn(var spawner: EnemySpawner; atTime: float)
    let i = floori(spawner.rate * atTime)
    if i != spawner.lastSpawn && noise(i, spawner.seed) >= spawner.threshold
        spawner.lastSpawn = i
        return true
    return false

def spawn_enemies(atTime: float)
    if should_spawn(rombSpawner, atTime)
        rombEnemies |> push(spawn(RombEnemy()))

def draw(quad: QuadEnemy)
    pass

def animate(var quad: QuadEnemy; dt, atTime: float)
    pass

def update(var quad: QuadEnemy; dt, atTime: float)
    pass
