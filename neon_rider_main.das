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

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("Neon Rider")

    road <- [[Road]]
    road.pos = float2(0., 0.65 * float(get_screen_height()))
    road.step  = 0.01
    road.scale = 80.

    car <- [[Car]]
    car.pos = float2(128., 256.)
    car.dir = float2(1., 0.)
    car.up  = float2(0., -1.)
    car.wheelRadius = 24.
    car.wheelsDistance  = 88.
    car.rearWheelOffset = 32.
    car.frontWheelPos = car.pos + car.dir * (car.wheelsDistance - car.rearWheelOffset)
    car.rearWheelPos  = car.pos - car.dir * car.rearWheelOffset

    car.gunPos = float2(128., -21.)
    car.gunLength = 45.
    car.shootFreq = 1./10.

    let springLen = 38.
    car.frontSpring = [[Spring length=springLen, dir=car.up, from=car.frontWheelPos, to=car.frontWheelPos + car.up * springLen]]
    car.rearSpring  = [[Spring length=springLen, dir=car.up, from=car.rearWheelPos, to=car.rearWheelPos + car.up * springLen]]

    car.frontSpring.curLength = springLen
    car.rearSpring.curLength = springLen

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    elif get_key_down(VK_RIGHT) || get_key_down(VK_D)
        car.speed = 256.
    elif get_key_down(VK_LEFT) || get_key_down(VK_A)
        car.speed = -64.
    elif get_key_up(VK_LEFT) || get_key_up(VK_RIGHT) || get_key_up(VK_A) || get_key_up(VK_D)
        car.speed = 0.

    let atTime = get_time_after_start()

    spawn_enemies(atTime)

    road.speed  = 3.
    road.offset = road.speed * atTime

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

    projectiles |> erase_by_offscreen()
    projectiles |> erase_by_ttl()

    erase_dead_whit_fx()

    update_particles(dt)

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    // let msg = "{romb_spawn_fn(get_time_after_start())}"
    // set_font_size(16)
    // text_out(10, 10, msg, 0xFFFFFFFF)

    enable_premultiplied_alpha_blend()

    road |> draw()
    car |> draw()

    draw_enemies()

    for p in projectiles
        let dir = normalize(p.vel)
        let from = p.pos - dir * 4.
        let to   = p.pos + dir * 4.
        dotTexture |> draw_segment(from, to, 0xFFFFFF)

    draw_particles()

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
