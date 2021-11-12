require daslib/media

require random

require common
require math_utils
require draw_utils
require road
require car
require enemies
require particles

// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

// TODO
// - Enemy: Chain (from behind)
// - Healthbar as body fill color
// - Red flame on the left wall - Danger area
// - Jump as attack
// - Holes int the ground
// - Bonuses
// - Different weapons: rockets, multi projectiles, lasers etc.
// - Global scale - more enemies on the screen etc.

var projectiles: array<Projectile>

def shoot(var car: Car)
    let atTime = get_time_after_start()
    let dt = atTime - car.lastShootAtTime
    if dt >= car.shootFreq
        car.lastShootAtTime = atTime

        var p = Projectile()
        p.pos = car.gunWorldPos + car.gunWorldDir * car.gunLength
        p.vel = car.gunWorldDir * 800.
        projectiles |> push(p)

let warpDuration = 0.5
var warpTime = warpDuration

def resize(var car: Car; scale: float)
    car.scale = scale
    car.wheelRadius = 24. * car.scale
    car.wheelsDistance  = 88. * car.scale
    car.rearWheelOffset = 32. * car.scale
    car.frontWheelPos = car.pos + car.dir * (car.wheelsDistance - car.rearWheelOffset)
    car.rearWheelPos  = car.pos - car.dir * car.rearWheelOffset
    car.center = float2(70., 0.) * car.scale
    car.hitRadius = 64. * car.scale

    car.gunPos = float2(128., -21.) * car.scale
    car.gunLength = 45. * car.scale
    car.shootFreq = 1./10.

    car.hitBox = float4(0., -30., 150., 30.) * car.scale

    let springLen = 38. * car.scale
    car.frontSpring = [[Spring length=springLen, dir=car.up, from=car.frontWheelPos, to=car.frontWheelPos + car.up * springLen]]
    car.rearSpring  = [[Spring length=springLen, dir=car.up, from=car.rearWheelPos, to=car.rearWheelPos + car.up * springLen]]

    car.frontSpring.curLength = springLen
    car.rearSpring.curLength = springLen

def restart()
    projectiles |> clear()

    clear_enemies()

    car <- [[Car]]
    car.pos = float2(128., 256.)
    car.dir = float2(1., 0.)
    car.up  = float2(0., -1.)
    car.alpha = 0.
    car.maxHp = 3.
    car.hp = car.maxHp

    car |> resize(0.5 /* scale */)

    warpTime = warpDuration
    if warpTime > 0.
        warp(car.pos - float2(0., 30.), warpTime)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("Neon Rider")

    road <- [[Road]]
    road.pos = float2(0., 0.65 * float(get_screen_height()))
    road.step  = 0.01
    road.scale = 80.

    restart()

    wall_of_file(float2(0., 0.5 * float(get_screen_height())), 1.)
    wall_of_file(float2(float(get_screen_width()), 0.5 * float(get_screen_height())), -1.)

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    elif get_key_down(VK_RIGHT) || get_key_down(VK_D)
        car.speed = 256.
    elif get_key_down(VK_LEFT) || get_key_down(VK_A)
        car.speed = -128.
    elif get_key_up(VK_LEFT) || get_key_up(VK_RIGHT) || get_key_up(VK_A) || get_key_up(VK_D)
        car.speed = 0.

    update_particles(dt)

    let wasWarpTime = warpTime
    warpTime -= dt

    let atTime = get_time_after_start()

    road.speed  = 3.
    road.offset = road.speed * atTime

    if wasWarpTime > 0.
        let t = (warpDuration - warpTime) / warpDuration
        car.alpha = lerp(0., 1., t)
        car |> resize(lerp(0.5, 0.95, t))
        return

    spawn_enemies(atTime)

    car |> update(road, dt)

    if get_mouse_button(MB_LEFT)
        car |> shoot()
    else
        car.lastShootAtTime = 0.

    projectiles |> integrate(dt)

    animate_enemies(dt, atTime)
    update_enemies(dt, atTime)
    integrate_enemies(dt)

    for p in projectiles
        p |> hit_enemies()

    car |> hit_car_by_enemies()

    projectiles |> erase_by_offscreen()
    projectiles |> erase_by_ttl()

    erase_dead_whit_fx()

    if car.hp < 0. || car.worldCenter.x < 0. || car.worldCenter.x > float(get_screen_width())
        restart()

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    // let msg = "{romb_spawn_fn(get_time_after_start())}"
    // set_font_size(16)
    // text_out(10, 10, msg, 0xFFFFFFFF)

    // transform2d_push()
    // transform2d_scale(float2(0.5, 0.5), float2())

    enable_premultiplied_alpha_blend()

    car |> draw()
    road |> draw()

    // let wBox = float4(car.pos + car.hitBox.xy, car.pos + car.hitBox.zw)
    // line(wBox.x, wBox.y, wBox.z, wBox.w, 0xFFFFFFFF)

    // circle(car.worldCenter.x, car.worldCenter.y, car.hitRadius, 0xFFFFFFFF)

    draw_particles()

    if warpTime <= 0.
        draw_enemies()

        for p in projectiles
            let dir = normalize(p.vel)
            let from = p.pos - dir * 4.
            let to   = p.pos + dir * 4.
            dotTexture |> draw_segment(from, to, 0xFFFFFF)

    // let wGunPos = rotate(car.tm, car.gunPos) + car.pos
    // circle(wGunPos.x, wGunPos.y, 2.f, 0xFFFFFFFF)

    // let mp = get_mouse_position()
    // line(wGunPos.x, wGunPos.y, mp.x, mp.y, 0xFFFFFFFF)

    // let itm = inverse(car.tm)
    // let dir = rotate(itm, normalize(mp - wGunPos))
    // car.gunAngle = atan2(dir.y, dir.x)

    // let lp = float2(128.f, 0.f)
    // let wp = rotate(car.tm, lp) + car.pos
    // circle(wp.x, wp.y, 32.f, 0xFFFFFFFF)

    // let itm = inverse(car.tm)
    // let lp0 = rotate(itm, wp - car.pos) 
    // msg = "{lp0}"

    // let points = [[auto[] float2(64.f, 64.f); float2(128.f, 64.f); float2(128.f, 128.f)]]
    // let step = 0.1
    // draw_bezier(points, step, 1., 0xF8F8FF)

    disable_alpha_blend()

    // transform2d_pop()