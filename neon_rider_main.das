require daslib/media

require utils
require road
require car

// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

var road: Road
var car: Car

let dotTexture = create_segment_texture(0.4 /* glow_intencity */)
let dotTextureNoGlow = create_segment_texture(0.01 /* glow_intencity */)
let dotTextureLowGlow = create_segment_texture(0.2 /* glow_intencity */)
let dotTextureHighGlow = create_segment_texture(0.8 /* glow_intencity */)

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

        // line(prevTop.x, prevTop.y, rt.x, rt.y, 0xFFFFFFFF)
        // line(prevBottom.x, prevBottom.y, rb.x, rb.y, 0xFFFFFFFF)

        // line(from.x, from.y, to.x, to.y, 0xFFFFFFFF)
        // line(to.x, to.y, to.x + n.x * hh, to.y + n.y * hh, 0xFFFFFFFF)
        
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

def find_contact_with_road(pos: float2; radius: float)
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

def find_contact_with_road(from, to: float2; radius: float; step: float)
    let velStep = step * normalize(to - from)
    let maxDist = length(to - from)
    var d = maxDist

    var contact := INVALID_CONTACT
    var center = to

    var p = from
    while d >= 0.
        let c = find_contact_with_road(p, radius)
        if c.depth >= 0.
            contact := c
            center = p
            break

        p += velStep
        d -= step

    let t = maxDist >= 1.e-5 ? length(center - from) / maxDist : 1.

    return [[RoadContact contact=contact, center=center, t=t]]

def draw(c: Car)
    transform2d_push()
    let dir = normalize(c.frontSpring.to - c.rearSpring.to)
    transform2d_translate(c.rearSpring.to - dir * c.rearWheelOffset)
    transform2d_rotate(asin(dir.y))

    let bodyPoints = [[auto[] float2(0., 16.);    // 0
                              float2(0., -16.);   // 1
                              float2(32., -48.);  // 2
                              float2(96., -48.);  // 3
                              float2(128., -16.);  // 4
                              float2(192., -16.);  // 5
                              float2(192., 16.);  // 6
                              float2(176., 16.);  // 7
                              float2(166., 8.);  // 8
                              float2(150., 8.);  // 9
                              float2(140., 16.);  // 10
                              float2(60., 16.);  // 11
                              float2(50., 8.);  // 12
                              float2(34., 8.);  // 13
                              float2(24., 16.);   // 14
                              float2(0., 16.)   // 15
                     ]]

    let bodyColor = 0x4169E1
    let bodyScale = 0.75
    for i in range(length(bodyPoints) - 1)
        draw_segment(dotTextureLowGlow, bodyPoints[i] * bodyScale, bodyPoints[i + 1] * bodyScale, bodyColor)

    let wheelsColor = 0xD2691E
    transform2d_pop()

    let step = 0.25f
    let stepsCount = floori(2.f * PI / step)

    transform2d_push()
    transform2d_translate(c.frontWheelPos)
    transform2d_rotate(c.frontWheelAngle)
    draw_circle(dotTexture, float2(), c.wheelRadius, wheelsColor)
    draw_circle(dotTextureLowGlow, float2(), c.wheelRadius * 0.25, wheelsColor)

    for i in range(stepsCount)
        let x0 = c.wheelRadius * cos(float(i) * step)
        let y0 = c.wheelRadius * sin(float(i) * step)
        let x1 = (c.wheelRadius + 4.) * cos(float(i) * step)
        let y1 = (c.wheelRadius + 4.) * sin(float(i) * step)
        draw_segment(dotTextureNoGlow, float2(x0, y0), float2(x1, y1), wheelsColor)

    transform2d_pop()

    transform2d_push()
    transform2d_translate(c.rearWheelPos)
    transform2d_rotate(c.rearWheelAngle)
    draw_circle(dotTexture, float2(), c.wheelRadius, wheelsColor)
    draw_circle(dotTextureLowGlow, float2(), c.wheelRadius * 0.25, wheelsColor)

    for i in range(stepsCount)
        let x0 = c.wheelRadius * cos(float(i) * step)
        let y0 = c.wheelRadius * sin(float(i) * step)
        let x1 = (c.wheelRadius + 4.) * cos(float(i) * step)
        let y1 = (c.wheelRadius + 4.) * sin(float(i) * step)
        draw_segment(dotTextureNoGlow, float2(x0, y0), float2(x1, y1), wheelsColor)

    transform2d_pop()

var msg: string

def solve_car_road_contact(var car: Car)
    let fricMu = 0.15
    let eps = 0.5

    let roadVel = 1. * float2(-road.speed, 0.)
    let relRoadVel  = car.frontWheelVel - roadVel

    let wishFrontWheelPos = car.frontWheelPos - roadVel
    let wishRearWheelPos  = car.rearWheelPos - roadVel

    let frontWheelDir = normalize(wishFrontWheelPos - car.wasFrontWheelPos)
    let rearWheelDir  = normalize(wishRearWheelPos - car.wasRearWheelPos)
    car.frontWheelDir = frontWheelDir
    car.rearWheelDir = rearWheelDir

    let frontDownC = find_contact_with_road(car.frontWheelPos - float2(0., 2.), car.frontWheelPos + float2(0., 4.), car.wheelRadius, 0.5 /* step */)
    if frontDownC.contact.depth >= 0.
        car.frontWheelFriction = -perp(frontDownC.contact.normal)
        // car.frontWheelOmega -= 0.1 * fricMu * dot(car.frontWheelFriction, car.frontWheelVel)
    else
        car.frontWheelFriction = float2()

    let rearDownC = find_contact_with_road(car.rearWheelPos - float2(0., 2.), car.rearWheelPos + float2(0., 4.), car.wheelRadius, 0.5 /* step */)
    if rearDownC.contact.depth >= 0.
        car.rearWheelFriction = -perp(rearDownC.contact.normal)
        // car.rearWheelOmega -= 1. * fricMu * dot(car.rearWheelFriction, car.rearWheelVel)
    else
        car.rearWheelFriction = float2()

    let fwdC = find_contact_with_road(car.frontWheelPos, wishFrontWheelPos, car.wheelRadius, 0.5 /* step */)
    if fwdC.contact.depth >= 0.
        // let posD = dot(car.frontWheelPos - fwdC.center, fwdC.contact.normal)
        // if posD < eps
        //     msg="{fwdC.contact.depth}"
        //     car.frontWheelPos += (eps - posD) * fwdC.contact.normal

        let d = dot(relRoadVel, fwdC.contact.normal)
        if d < 0.
            car.frontWheelVel -= d * fwdC.contact.normal

        // wall = [-10,0]
        // ball = [0,0]
        // n = [-1,0]
        // relVel = [0,0] - [-10,0] = [10,0]
        // d = dot([10,0], [-1,0]) = -10
        // ball = [0,0] - (-10) * [-1,0] = [0,0] - [10,0] = [-10,0]

    let frontTraceFrom = car.wasFrontWheelPos - 4. * frontWheelDir
    let frontTraceTo   = wishFrontWheelPos    + 4. * frontWheelDir
    car.frontTraceFrom = frontTraceFrom
    car.frontTraceTo   = frontTraceTo

    let frontC = find_contact_with_road(frontTraceFrom, frontTraceTo, car.wheelRadius, 0.5 /* step */)
    if frontC.contact.depth >= 0.
        let posD = dot(car.frontWheelPos - frontC.center, frontC.contact.normal)
        if posD < eps
            car.frontWheelPos += (eps - posD) * frontC.contact.normal
        car.frontWheelContact = frontC

        let n = frontC.contact.normal
        let d = dot(car.frontWheelVel, n)
        if d < 0.f
            car.frontWheelVel -= d * n

        let fric  = -perp(n)
        let fricD = dot(fric, car.frontWheelVel)

        car.frontWheelVel -= fricMu * fricD * fric

    let rearTraceFrom = car.wasRearWheelPos - 4. * rearWheelDir
    let rearTraceTo   = wishRearWheelPos    + 4. * rearWheelDir

    let rearC = find_contact_with_road(rearTraceFrom, rearTraceTo, car.wheelRadius, 0.5 /* step */)
    if rearC.contact.depth >= 0.
        let posD = dot(car.rearWheelPos - rearC.center, rearC.contact.normal)
        if posD < eps
            car.rearWheelPos += (eps - posD) * rearC.contact.normal
        car.rearWheelContact = rearC

        let d = dot(car.rearWheelVel, rearC.contact.normal)
        if d < 0.f
            car.rearWheelVel -= d * rearC.contact.normal

        let fric  = -perp(rearC.contact.normal)
        let fricD = dot(fric, car.rearWheelVel)

        car.rearWheelVel -= fricMu * fricD * fric

        // car.rearWheelOmega -= 1. * fricMu * fricD

def approach(from, to; dt, viscosity: float)
    if viscosity < 1e-9
        return to

    return from + (1. - exp(-dt / viscosity)) * (to - from)

def solve(var s: Spring; dt: float)
    s.curLength = approach(s.curLength, s.wishLength, dt, 0.2)
    s.to = s.from + s.curLength * s.dir

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

    let springLen = 32.
    car.frontSpring = [[Spring stiffness=10., length=springLen, dir=car.up, from=car.frontWheelPos, to=car.frontWheelPos + car.up * springLen]]
    car.rearSpring  = [[Spring stiffness=10., length=springLen, dir=car.up, from=car.rearWheelPos, to=car.rearWheelPos + car.up * springLen]]

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

    car.wasFrontWheelPos = car.frontWheelPos
    car.wasRearWheelPos  = car.rearWheelPos

    let wasFrontWheelVel = car.frontWheelVel
    let wasRearWheelVel = car.rearWheelVel

    // car.vel += float2(0.f, 25. * 9.81 * dt)
    car.frontWheelVel += float2(0., 25. * 9.81) * dt
    car.rearWheelVel  += float2(0., 25. * 9.81) * dt

    car.frontWheelOmega -= 4.f * dot(car.frontWheelDir, car.frontWheelFriction)
    car.frontWheelOmega += car.speed * dt
    car.frontWheelAngle += car.frontWheelOmega * dt
    car.frontWheelOmega = 0.01 * car.frontWheelOmega

    car.rearWheelOmega -= 4.f * dot(car.rearWheelDir, car.rearWheelFriction)
    car.rearWheelAngle += car.rearWheelOmega * dt
    car.rearWheelOmega = 0.01 * car.rearWheelOmega

    car.frontWheelPos += car.frontWheelVel * dt
    car.rearWheelPos  += car.rearWheelVel * dt

    let wheelsDir = normalize(car.frontWheelPos - car.rearWheelPos)
    let wheelsD   = dot(car.rearWheelVel, wheelsDir)
    car.rearWheelVel += -wheelsD * wheelsDir

    let wheeilsDist = length(car.frontWheelPos - car.rearWheelPos)
    car.rearWheelPos += 0.75 * (wheeilsDist - car.wheelsDistance) * wheelsDir

    // let wishCarDir = normalize(car.frontWheelPos - car.rearWheelPos)
    // let wishCarUp = float2(wishCarDir.y, -wishCarDir.x)
    // car.frontSpring.wishTo = car.frontWheelPos + wishCarUp * car.frontSpring.length
    // car.rearSpring.wishTo  = car.rearWheelPos  + wishCarUp * car.rearSpring.length

    car |> solve_car_road_contact()

    if car.speed != 0.
        let s = -dot(car.frontWheelVel, car.frontWheelFriction)
        car.frontWheelVel -= (car.speed - s) * car.frontWheelFriction

    car.dir = normalize(car.frontWheelPos - car.rearWheelPos)
    car.up = float2(car.dir.y, -car.dir.x)
    car.pos = 0.5 * (car.frontWheelPos + car.rearWheelPos)
    car.vel = 0.5 * (car.frontWheelVel + car.rearWheelVel)

    let frontWheelPosDelta = 10.f * dot(car.frontWheelPos - car.wasFrontWheelPos, car.up)
    let rearWheelPosDelta  = 10.f * dot(car.rearWheelPos - car.wasRearWheelPos, car.up)

    car.frontSpring.from = car.frontWheelPos
    car.frontSpring.dir  = car.up
    car.frontSpring.wishLength = car.frontSpring.length - clamp(frontWheelPosDelta, -10., 10.)
    // car.frontSpring.wishLength = car.frontSpring.length
    car.frontSpring |> solve(dt)

    car.rearSpring.from = car.rearWheelPos
    car.rearSpring.dir  = car.up
    car.rearSpring.wishLength = car.rearSpring.length - clamp(rearWheelPosDelta, -10., 10.)
    // car.rearSpring.wishLength = car.frontSpring.length
    car.rearSpring |> solve(dt)

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    set_font_size(16)
    text_out(10, 10, msg, 0xFFFFFFFF)

    enable_premultiplied_alpha_blend()

    road |> draw()
    car |> draw()

    disable_alpha_blend()
