require daslib/media

require utils
require math_utils
require draw_utils
require road

require math

struct Car
    pos: float2
    vel: float2
    dir: float2
    up: float2

    wheelRadius: float
    wheelsDistance: float
    rearWheelOffset: float

    frontWheelPos: float2
    frontWheelVel: float2
    rearWheelPos: float2
    rearWheelVel: float2

    frontWheelAngle: float
    frontWheelOmega: float

    rearWheelAngle: float
    rearWheelOmega: float

    wasFrontWheelPos: float2
    wasRearWheelPos: float2

    frontWheelContact: RoadContact
    rearWheelContact: RoadContact

    frontWheelFriction: float2
    rearWheelFriction: float2

    frontWheelDir: float2
    rearWheelDir: float2

    speed: float

    frontSpring: Spring
    rearSpring: Spring

    gunPos: float2
    gunAngle: float

    tm: float4 

    // Debug
    frontTraceFrom: float2
    frontTraceTo: float2

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

    // Gun
    let gunDir = float2(cos(c.gunAngle), sin(c.gunAngle))
    let gunLen = 45.
    dotTextureNoGlow |> draw_arc(float2(128., -13.), 16.f, 180., 360., bodyColor)
    dotTextureNoGlow |> draw_segment(c.gunPos, c.gunPos + gunDir * gunLen, bodyColor)

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

def solve_car_road_contact(var car: Car; road: Road)
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

    let frontDownC = find_contact_with_road(road, car.frontWheelPos - float2(0., 2.), car.frontWheelPos + float2(0., 4.), car.wheelRadius, 0.5 /* step */)
    if frontDownC.contact.depth >= 0.
        car.frontWheelFriction = -perp(frontDownC.contact.normal)
    else
        car.frontWheelFriction = float2()

    let rearDownC = find_contact_with_road(road, car.rearWheelPos - float2(0., 2.), car.rearWheelPos + float2(0., 4.), car.wheelRadius, 0.5 /* step */)
    if rearDownC.contact.depth >= 0.
        car.rearWheelFriction = -perp(rearDownC.contact.normal)
    else
        car.rearWheelFriction = float2()

    let fwdC = find_contact_with_road(road, car.frontWheelPos, wishFrontWheelPos, car.wheelRadius, 0.5 /* step */)
    if fwdC.contact.depth >= 0.
        let d = dot(relRoadVel, fwdC.contact.normal)
        if d < 0.
            car.frontWheelVel -= d * fwdC.contact.normal

    let frontTraceFrom = car.wasFrontWheelPos - 4. * frontWheelDir
    let frontTraceTo   = wishFrontWheelPos    + 4. * frontWheelDir
    car.frontTraceFrom = frontTraceFrom
    car.frontTraceTo   = frontTraceTo

    let frontC = find_contact_with_road(road, frontTraceFrom, frontTraceTo, car.wheelRadius, 0.5 /* step */)
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

    let rearC = find_contact_with_road(road, rearTraceFrom, rearTraceTo, car.wheelRadius, 0.5 /* step */)
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

def solve(var s: Spring; dt: float)
    s.curLength = approach(s.curLength, s.wishLength, dt, 0.2)
    s.to = s.from + s.curLength * s.dir

def update(var car: Car; road: Road; dt: float)
    car.wasFrontWheelPos = car.frontWheelPos
    car.wasRearWheelPos  = car.rearWheelPos

    let wasFrontWheelVel = car.frontWheelVel
    let wasRearWheelVel = car.rearWheelVel

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

    car |> solve_car_road_contact(road)

    if car.speed != 0.
        let s = -dot(car.frontWheelVel, car.frontWheelFriction)
        car.frontWheelVel -= (car.speed - s) * car.frontWheelFriction

    car.dir = normalize(car.frontWheelPos - car.rearWheelPos)
    car.up = float2(car.dir.y, -car.dir.x)
    car.vel = 0.5 * (car.frontWheelVel + car.rearWheelVel)

    let frontWheelPosDelta = 10.f * dot(car.frontWheelPos - car.wasFrontWheelPos, car.up)
    let rearWheelPosDelta  = 10.f * dot(car.rearWheelPos - car.wasRearWheelPos, car.up)

    car.frontSpring.from = car.frontWheelPos
    car.frontSpring.dir  = car.up
    car.frontSpring.wishLength = car.frontSpring.length - clamp(frontWheelPosDelta, -10., 10.)
    car.frontSpring |> solve(dt)

    car.rearSpring.from = car.rearWheelPos
    car.rearSpring.dir  = car.up
    car.rearSpring.wishLength = car.rearSpring.length - clamp(rearWheelPosDelta, -10., 10.)
    car.rearSpring |> solve(dt)

    let dir = normalize(car.frontSpring.to - car.rearSpring.to)

    car.pos = car.rearSpring.to - dir * car.rearWheelOffset
    car.tm  = make_tm(asin(dir.y))

    let wGunPos = rotate(car.tm, car.gunPos) + car.pos

    let mp = get_mouse_position()
    let wishGunDir = normalize(mp - wGunPos)
    car.gunAngle = atan2(wishGunDir.y, wishGunDir.x)
