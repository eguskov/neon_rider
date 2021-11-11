require daslib/media

require utils
require math_utils
require draw_utils
require road
require car

// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

var road: Road
var car: Car

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
    elif get_key_down(VK_RIGHT)
        car.speed = 256.
    elif get_key_down(VK_LEFT)
        car.speed = -64.
    elif get_key_up(VK_LEFT) || get_key_up(VK_RIGHT)
        car.speed = 0.

    road.speed  = 3.
    road.offset = road.speed * get_time_after_start()

    car |> update(road, dt)

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    // set_font_size(16)
    // text_out(10, 10, msg, 0xFFFFFFFF)

    enable_premultiplied_alpha_blend()

    road |> draw()
    car |> draw()

    // let wGunPos = rotate(car.tm, car.gunPos) + car.pos
    // circle(wGunPos.x, wGunPos.y, 2.f, 0xFFFFFFFF)

    // let mp = get_mouse_position()
    // let dir = normalize(mp - wGunPos)
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
