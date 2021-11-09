require daslib/media
// options debugger            // uncomment for debug in VS Code
// require daslib/debug        // uncomment for debug in VS Code

struct Rect
    img: Image
    bloom: Image

    center: float2
    angle: float

struct Road
    segmentImg: Image

    pos: float2

    offset: float
    scale: float
    step: float

struct Car
    bodyImg: Image
    frontWheelImg: Image
    rearWheelImg: Image

    pos: float2
    vel: float2
    dir: float2
    up: float2

    frontWheelPos: float2
    frontWheelVel: float2
    rearWheelPos: float2
    rearWheelVel: float2

    frontWheelContact: RoadContact
    rearWheelContact: RoadContact

    frontWheelFriction: float2
    rearWheelFriction: float2

    frontWheelTrace: float2
    frontWheelTraceTo: float2

    speed: float

var road: Road
var car: Car

var rects: array<Rect>

def cross(a, b: float2)
    return a.x * b.y - a.y * b.x

def proj(a, b: float2)
    return normalize(b) * dot(a, b)

def perp(a, b: float2)
    return a - proj(a, b)

def perp(a: float2)
    return float2(-a.y, a.x)

def noise(pos: int; seed: uint)
    let maxrndfloat = 16777215.0 // float can only hold 23-bits integers without data loss
    let maxrndfloatmask = 16777215u // (1<24)-1
    return float(uint_noise_1D(pos, seed) & maxrndfloatmask) / maxrndfloat // [0,1]

struct Contact
    pos: float2
    normal: float2
    depth: float

let INVALID_CONTACT = [[Contact pos=float2(), normal=float2(), depth=-1.]]

def contact_circle_to_line(center: float2; radius: float; line_from, line_to: float2): Contact
    // let lineDir      = normalize(line_to - line_from)
    // let dirToCriclse = center - line_from
    // let distToLine = abs(cross(dirToCriclse, lineDir))
    // if distToLine > radius
    //     return INVALID_CONTACT

    // if dot(dirToCriclse, lineDir) < 0. || dot(center - line_to, lineDir) > 0.
    //     return INVALID_CONTACT

    // let pos    = line_from + proj(dirToCriclse, lineDir)
    // let normal = perp(dirToCriclse, lineDir)
    // let len    = length(normal)
    // let d      = radius - len

    // return [[Contact pos=pos, normal=normal * (1./len), depth=d]]

    let to   = line_to - center
    let from = line_from - center

    var d = to - from
    let lenSq = length_sq(d)
    d /= sqrt(lenSq)

    let n = -perp(d)

    let r2 = radius * radius
    if length_sq(from) <= r2 && length_sq(to) <= r2
        let c = center + 0.5 * (from + to)
        return [[Contact pos=c, normal=n, depth=radius - length(center - c)]]

    let D = cross(from, to)
    let t = radius * radius * lenSq - D * D
    if t < 0.
        return [[Contact depth=-1.]]
    
    let s = sqrt(t)
    let sgnY = d.y < 0. ? -1. : 1.
    let c0 = center + float2(D * d.y + sgnY * d.x * s, -D * d.x + abs(d.y) * s) / lenSq
    let c1 = center + float2(D * d.y - sgnY * d.x * s, -D * d.x - abs(d.y) * s) / lenSq
    let c  = 0.5 * (c0 + c1)
    let prj = dot(c - line_from, d)
    if prj < 0. || prj * prj > lenSq
        return [[Contact depth=-1.]]

    return [[Contact pos=c, normal=n, depth=radius - length(center - c)]]

def color_to_float3(c: uint)
    let r = (c >> 16u) & 0xFF
    let g = (c >>  8u) & 0xFF
    let b = (c >>  0u) & 0xFF
    return float3(float(r)/255., float(g)/255., float(b)/255.)

let weights = [[auto[] 0.227027; 0.1945946; 0.1216216; 0.054054; 0.016216]]

def gauss_blur_horizontal(var buffer: array<float3>; w, h: int)
    for y in range(h)
        for x in range(w)
            var c & = buffer[x + y * w]
            c *= weights[0]
            for i in range(1, 5)
                if x + i < w
                    c += buffer[(x + i) + y * w] * weights[i]
                if x - i >= 0
                    c += buffer[(x - i) + y * w] * weights[i]

def gauss_blur_vertical(var buffer: array<float3>; w, h: int)
    for y in range(h)
        for x in range(w)
            var c & = buffer[x + y * w]
            c *= weights[0]
            for i in range(1, 5)
                if y + i < h
                    c += buffer[x + (y + i) * w] * weights[i]
                if y - i >= 0
                    c += buffer[x + (y - i) * w] * weights[i]

def blend(var img0: Image; img1: Image)
    for y in range(img0.height)
        for x in range(img0.width)
            let exposure = 0.75
            var c0 = color_to_float3(img0 |> get_pixel(x, y))
            let c1 = color_to_float3(img1 |> get_pixel(x, y))
            c0 += c1
            var r = float3(1.0) - exp(-c0 * exposure)
            r = pow(r, float3(1. / 2.2))
            img0 |> set_pixel(x, y, make_color(r.x, r.y, r.z, 0.))

def ping_pong_blur(var buffer: array<float3>; width, height: int; steps: int)
    for i in range(steps)
        if (i % 2) == 0
            buffer |> gauss_blur_horizontal(width, height)
        else
            buffer |> gauss_blur_vertical(width, height)

def bloom(img: Image; intencity: float)
    let bloomExtraSize = int2(32, 32)
    let bloomExtraHalfSize = bloomExtraSize / int2(2, 2)
    var bloomImg <- create_image(img.width + bloomExtraSize.x, img.height + bloomExtraSize.y)
    bloomImg |> set_image_smooth(true)

    var srcColors: array<uint>
    srcColors |> resize(img.width * img.height)

    img |> get_image_data(srcColors)

    var buffer: array<float3>
    var colors: array<uint>
    colors |> resize(bloomImg.width * bloomImg.height)
    buffer |> resize(bloomImg.width * bloomImg.height)

    for y in range(img.height)
        for x in range(img.width)
            let p = int2(x + bloomExtraHalfSize.x, y + bloomExtraHalfSize.y)
            colors[p.x + p.y * bloomImg.width] = srcColors[x + y * img.width]

    for i in range(length(colors))
        buffer[i] = color_to_float3(colors[i])

    buffer |> ping_pong_blur(bloomImg.width, bloomImg.height, 4)

    for i in range(length(buffer))
        let c = uint3(saturate(intencity * buffer[i]) * float3(255.f))
        colors[i] = ((c.x << 16u) & 0xFF0000) | ((c.y << 8u) & 0xFF00) | (c.z & 0xFF)

    bloomImg |> set_image_data(colors)

    return <- bloomImg

def gradient(w, h: int)
    var img <- create_image(w, h)
    img |> set_image_smooth(true)

    for y in range(img.height)
        for x in range(img.width)
            let t = abs((float(y) / float(img.height) - 0.5) / 0.5)
            let c = 1. - t * t * 1.
            img |> set_pixel(x, y, make_color(c, 0.))

    return <- img

def make_rect(w, h: int)
    var r <- [[Rect]]

    r.img <- create_image(w, h)
    r.img |> set_image_smooth(true)
    for y in range(r.img.height)
        for x in range(r.img.width)
            r.img |> set_pixel(x, y, make_color(1., 0.))

    r.bloom <- bloom(r.img, 2.f)

    return <- r

def set_circle_pixels(var img; xc, yc, x, y: int; color: uint)
    img |> set_pixel(xc + x, yc + y, color)
    img |> set_pixel(xc - x, yc + y, color)
    img |> set_pixel(xc + x, yc - y, color)
    img |> set_pixel(xc - x, yc - y, color)
    img |> set_pixel(xc + y, yc + x, color)
    img |> set_pixel(xc - y, yc + x, color)
    img |> set_pixel(xc + y, yc - x, color)
    img |> set_pixel(xc - y, yc - x, color)
 
def draw_circle(var img; xc, yc, r: int; color: uint)
    var x = 0
    var y = r
    var d = 3 - 2 * r

    img |> set_circle_pixels(xc, yc, x, y, color)

    while y >= x
        x++

        if d > 0
            y--
            d = d + 4 * (x - y) + 10
        else
            d = d + 4 * x + 6

        img |> set_circle_pixels(xc, yc, x, y, color)

def make_circle(r, thickness: int)
    var img <- create_image(2 * r, 2 * r)
    img |> set_image_smooth(true)

    img |> draw_circle(r, r, r - 1, make_color(1., 0.f))
    for i in range(1, thickness)
        img |> draw_circle(r, r, r - 1 - i, make_color(1., 0.f))

    return <- img

def make_frame(w, h, thickness: int)
    var img <- create_image(w, h)
    img |> set_image_smooth(true)

    for y in range(thickness)
        for x in range(img.width)
            img |> set_pixel(x, y, make_color(1., 0.))

    for y in range(h - thickness, h)
        for x in range(img.width)
            img |> set_pixel(x, y, make_color(1., 0.))

    for y in range(img.height)
        for x in range(thickness)
            img |> set_pixel(x, y, make_color(1., 0.))

    for y in range(img.height)
        for x in range(w - thickness, w)
            img |> set_pixel(x, y, make_color(1., 0.))

    return <- img

def draw(r: Rect)
    let imgSz   = float2(r.img.width * 1, r.img.height * 1)
    let bloomScale = float2(1., 1.)
    let bloomSz = float2(r.bloom.width * 1, r.bloom.height * 1) * bloomScale

    transform2d_push()

    transform2d_translate(r.center)
    transform2d_rotate(r.angle)

    let pos = -0.5 * imgSz
    // r.img |> draw_image(pos.x, pos.y, make_color(0.1, 1., 0.1), imgSz)

    let bloomPos = pos + 0.5 * (imgSz - bloomSz)
    r.bloom |> draw_image(bloomPos.x, bloomPos.y, make_color(0.35, 1., 0.35), bloomSz)

    transform2d_pop()

def draw_segment(img: Image; from, to: float2)
    let d = normalize(to - from)
    let n = float2(-d.y, d.x)
    let w = float(img.width)
    let h = float(img.height)
    let hh = 0.5 * h

    let coords <- to_array([[auto[] from - n * hh/* float2(0., 16.) */;
                                    from + n * hh/* float2(0., 0.) */;
                                    to - n * hh/* float2(16., 16.) */;
                                    to + n * hh/* float2(16., 0.) */]])
    let uvs    <- to_array([[auto[] float2(0., h); float2(0., 0.); float2(w, h); float2(w, 0.)]])

    img |> draw_triangle_strip(coords, uvs, make_color(0.1, 1., 0.1))

def draw_segment(img: Image; lt, rt, lb, rb: float2)
    let w = float(img.width)
    let h = float(img.height)
    let coords <- to_array([[auto[] lb; lt; rb; rt]])
    let uvs    <- to_array([[auto[] float2(0., h); float2(0., 0.); float2(w, h); float2(w, 0.)]])
    img |> draw_triangle_strip(coords, uvs, make_color(0.1, 1., 0.1))

def hermit_interp(from, to, m0, m1, t: float)
    let t2 = t * t
    let t3 = t2 * t
    return (2. * t3 - 3. * t2 + 1.) * from + (t3 - 2. * t2 + t) * m0 + (-2. * t3 + 3. * t2) * to + (t3 - t2) * m1

def road_fn(x: float)
    let seed = 17u
    let cur  = noise(floori(x), seed)
    let next = noise(ceili(x), seed)
    let prev = noise(floori(x) - 1, seed)
    let t = 1. - ceil(x) + x

    // return lerp(float(cur), float(next), 1. - k)

    let m0 = cur - prev
    let m1 = next - cur
    return hermit_interp(float(cur), float(next), m0, m1, t)
    // return sin(x)
    // return noise(floori(x), seed)

def road_point(r: Road; x: float)
    return float2(x, road_fn(x + r.offset)) * r.scale

def road_point_world(r: Road; x: float)
    return r.pos + float2(x, road_fn(x + r.offset)) * r.scale

def draw(r: Road)
    transform2d_push()
    transform2d_translate(r.pos)

    let h  = float(r.segmentImg.height)
    let hh = 0.5 * h

    var from = r |> road_point(0.)
   
    let firstTo = r |> road_point(r.step)
    let firstD  = normalize(firstTo - from)
    let firstN  = float2(-firstD.y, firstD.x)

    var prevTop    = from - firstN * hh
    var prevBottom = from + firstN * hh

    let maxSteps = ceili(float(get_screen_width()) / (r.step * r.scale)) + 1

    for i in range(1, maxSteps)
        let x = float(i) * r.step
        let to = r |> road_point(x)

        let d = normalize(to - from)
        let n = float2(-d.y, d.x)

        let rt = to - n * hh
        let rb = to + n * hh
  
        r.segmentImg |> draw_segment(prevTop, rt, prevBottom, rb)
        
        prevBottom = rb
        prevTop    = rt

        from = to

    transform2d_pop()

def find_contact_with_road(pos: float2; radius: float)
    let minPos = pos - float2(radius)
    let maxPos = pos + float2(radius)

    let rangeStart = ceili(minPos.x / (road.step * road.scale))
    let rangeCount = ceili((maxPos.x - minPos.x) / (road.step * road.scale))

    var from = road |> road_point_world(float(rangeStart - 1) * road.step)
    for i in range(rangeStart, rangeStart + rangeCount)
        let to = road |> road_point_world(float(i) * road.step)

        // line(from.x, from.y, to.x, to.y, make_color(1., 0.1, 0.1))

        let c = contact_circle_to_line(pos, radius, from, to)
        if c.depth >= 0.
            // circle(c.pos.x, c.pos.y, 2., make_color(1., 1., 1.))
            return c

        from = to

    return INVALID_CONTACT

struct RoadContact
    contact: Contact
    center: float2

def find_contact_with_road(from, to: float2; radius: float; step: float)
    let velStep = step * normalize(to - from)
    let maxDist = length(to - from)
    var d = maxDist

    var contact := INVALID_CONTACT
    var center = float2()

    var p = from
    while d > 0.
        let c = find_contact_with_road(p, radius)
        if c.depth >= 0.
            contact := c
            center = p/*  + c.normal * c.depth */
            break

        p += velStep
        d -= step

    return [[RoadContact contact=contact, center=center]]

def draw(c: Car)
    transform2d_push()
    transform2d_translate(c.pos - 16. * c.up)
    transform2d_rotate(asin(c.dir.y))
    c.bodyImg |> draw_image(-0.5 * float(c.bodyImg.width), -0.5 * float(c.bodyImg.width))
    transform2d_pop()
    c.frontWheelImg |> draw_image(c.frontWheelPos.x - 0.5 * float(c.frontWheelImg.width), c.frontWheelPos.y - 0.5 * float(c.frontWheelImg.height), make_color(1., .1, .1))
    c.rearWheelImg |> draw_image(c.rearWheelPos.x - 0.5 * float(c.rearWheelImg.width), c.rearWheelPos.y - 0.5 * float(c.rearWheelImg.height), make_color(1., .1, .1))

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("neon_rider")
    // set_antialiasing(4)

    road <- [[Road]]
    road.segmentImg <- gradient(8, 8)
    road.pos = float2(0., 0.5 * float(get_screen_height()))
    road.step  = 0.01
    road.scale = 80.

    rects |> resize(32)
    for r in rects
        r <- make_rect(256, 3)

    car <- [[Car]]
    car.pos = float2(64., 64.)
    car.dir = float2(1., 0.)
    car.up  = float2(0., -1.)
    car.frontWheelPos = car.pos + car.dir * 32.
    car.rearWheelPos  = car.pos - car.dir * 32.
    car.bodyImg <- bloom(make_frame(64, 32, 2), 3.f)
    car.frontWheelImg <- bloom(make_circle(16, 2), 3.f)
    car.rearWheelImg  <- bloom(make_circle(16, 2), 3.f)

var msg: string

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    elif get_key_down(VK_RIGHT)
        car.speed = 64.
    elif get_key_down(VK_LEFT)
        car.speed = -64.
    elif get_key_up(VK_LEFT) || get_key_up(VK_RIGHT)
        car.speed = 0.

    let atTime = 0.f * get_time_after_start()

    road.offset = atTime

    let warCarPos = car.pos
    let warCarFrontWheelPos = car.frontWheelPos
    let warCarRearWheelPos  = car.rearWheelPos

    // car.vel += float2(0.f, 25. * 9.81 * dt)
    car.frontWheelVel += float2(0., 25. * 9.81) * dt
    car.rearWheelVel  += float2(0., 25. * 9.81) * dt

    // car.frontWheelVel -= car.speed * dt * car.frontWheelFriction
    // car.rearWheelVel  -= car.speed * dt * car.rearWheelFriction

    msg = "{-dot(car.frontWheelVel, car.frontWheelFriction)}"

    // car.pos += car.vel * dt
    car.frontWheelPos += car.frontWheelVel * dt
    car.rearWheelPos  += car.rearWheelVel * dt

    let frontWheelDir = normalize(car.frontWheelPos - warCarFrontWheelPos)
    let rearWheelDir  = normalize(car.rearWheelPos - warCarRearWheelPos)

    let offset = float2(0. * car.speed * dt, 0.f)
    let fricMu = 0.15

    let eps = 0.1

    car.frontWheelTrace   = warCarFrontWheelPos - 1. * frontWheelDir + offset
    car.frontWheelTraceTo = car.frontWheelPos + eps * frontWheelDir + offset

    let downC = find_contact_with_road(car.frontWheelPos - float2(0., 2.), car.frontWheelPos + float2(0., 4.), 16.f/* radius */, 0.5 /* step */)
    if downC.contact.depth >= 0.
        car.frontWheelFriction = -perp(downC.contact.normal)
    else
        car.frontWheelFriction = float2() 

    let frontC = find_contact_with_road(warCarFrontWheelPos - 1. * frontWheelDir + offset, car.frontWheelPos + 4. * frontWheelDir + offset, 16.f/* radius */, 0.5 /* step */)
    if frontC.contact.depth >= 0.
        car.frontWheelPos = frontC.center + eps * frontC.contact.normal
        car.frontWheelContact = frontC

        let n = frontC.contact.normal
        let d = dot(car.frontWheelVel, n)
        if d < 0.f
            car.frontWheelVel -= d * n

        let fric  = -perp(n)
        let fricD = dot(fric, car.frontWheelVel)

        car.frontWheelVel -= fricMu * fricD * fric
        // car.frontWheelFriction = fric
    else
        car.frontWheelPos += offset
        // car.frontWheelFriction = float2()

    let rearC = find_contact_with_road(warCarRearWheelPos - 4. * rearWheelDir + offset, car.rearWheelPos + eps * rearWheelDir + offset, 16.f/* radius */, 0.5 /* step */)
    if rearC.contact.depth >= 0.
        car.rearWheelPos = rearC.center + eps * rearC.contact.normal
        car.rearWheelContact = rearC

        let d = dot(car.rearWheelVel, rearC.contact.normal)
        if d < 0.f
            car.rearWheelVel -= d * rearC.contact.normal

        let fric  = -perp(rearC.contact.normal)
        let fricD = dot(fric, car.rearWheelVel)

        car.rearWheelVel -= fricMu * fricD * fric
        car.rearWheelFriction = fric
    else
        car.rearWheelPos += offset
        car.rearWheelFriction = float2()

    if car.speed > 0.
        let s = -dot(car.frontWheelVel, car.frontWheelFriction)
        if s < car.speed
            car.frontWheelVel -= (car.speed - s) * car.frontWheelFriction

    let wheelsDir = normalize(car.frontWheelPos - car.rearWheelPos)
    let wheelsD   = dot(car.rearWheelVel, wheelsDir)
    car.rearWheelVel += -wheelsD * wheelsDir

    let wheeilsDist = length(car.frontWheelPos - car.rearWheelPos)
    // msg = "{wheeilsDist}"
    car.rearWheelPos += 0.75 * (wheeilsDist - 64.) * wheelsDir

    car.dir = normalize(car.frontWheelPos - car.rearWheelPos)
    car.up = float2(-car.dir.y, car.dir.x)
    car.pos = 0.5 * (car.frontWheelPos + car.rearWheelPos)
    car.vel = 0.5 * (car.frontWheelVel + car.rearWheelVel)

    for i in range(length(rects))
        let y = 32.f * sin(5.f * atTime + 0.1f * float(i+1))
        rects[i].center = float2(256.f + 8.f * float(i), 256.f + y)
        rects[i].angle += (0.15f * float(i+1)) * dt

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    set_font_size(16)
    text_out(10, 10, msg, 0xFFFFFFFF)

    // if car.frontWheelContact.contact.depth > 0.
    //     line(car.frontWheelContact.center.x, car.frontWheelContact.center.y,
    //          car.frontWheelContact.center.x + car.frontWheelContact.contact.normal.x * 50.f,
    //          car.frontWheelContact.center.y + car.frontWheelContact.contact.normal.y * 50.f, make_color(1.f, 1.f, 1.f))

    //     line(car.frontWheelContact.center.x, car.frontWheelContact.center.y,
    //          car.frontWheelContact.center.x + car.frontWheelFriction.x * 50.f,
    //          car.frontWheelContact.center.y + car.frontWheelFriction.y * 50.f, make_color(1.f, 0.f, 0.f))

    //     line(car.frontWheelContact.center.x, car.frontWheelContact.center.y,
    //          car.frontWheelContact.center.x + car.frontWheelVel.x * 50.f,
    //          car.frontWheelContact.center.y + car.frontWheelVel.y * 50.f, make_color(0.f, 1.f, 0.f))

    // circle(car.frontWheelTrace.x, car.frontWheelTrace.y, 16.f, make_color(0.f, 0.f, 1.f))
    // circle(car.frontWheelTraceTo.x, car.frontWheelTraceTo.y, 16.f, make_color(1.f, 0.f, 1.f))

    // if car.rearWheelContact.contact.depth > 0.
    //     line(car.rearWheelContact.center.x, car.rearWheelContact.center.y,
    //          car.rearWheelContact.center.x + car.rearWheelContact.contact.normal.x * 50.f,
    //          car.rearWheelContact.center.y + car.rearWheelContact.contact.normal.y * 50.f, make_color(1.f, 1.f, 1.f))

    //     line(car.rearWheelContact.center.x, car.rearWheelContact.center.y,
    //          car.rearWheelContact.center.x + car.rearWheelFriction.x * 50.f,
    //          car.rearWheelContact.center.y + car.rearWheelFriction.y * 50.f, make_color(1.f, 0.f, 0.f))

    //     line(car.rearWheelContact.center.x, car.rearWheelContact.center.y,
    //          car.rearWheelContact.center.x + car.rearWheelVel.x * 50.f,
    //          car.rearWheelContact.center.y + car.rearWheelVel.y * 50.f, make_color(0.f, 1.f, 0.f))

    enable_premultiplied_alpha_blend()

    road |> draw()

    car |> draw()

    let pos = float2(64.f/*  + 512.f * (sin(get_time_after_start()) + 1.f) */, 200.f)
    let radius = 16.f

    // wheel |> draw_image(pos.x - 0.5 * float(wheel.width), pos.y - 0.5 * float(wheel.height), make_color(1., 0.1, .1))

    // let vel = float2(0.f, 300.f)
    // let dt = 1.
    // let nextPos = pos + vel * dt
    // let minPos = pos - float2(radius)
    // let maxPos = nextPos + float2(radius)

    // let c = find_contact_with_road(pos, nextPos, radius, 2. /* step */)
    // if c.contact.depth >= 0.f
    //     // circle(c.center.x, c.center.y, radius, make_color(.1, 1., 0.1))
    //     wheel |> draw_image(c.center.x - 0.5 * float(wheel.width), c.center.y - 0.5 * float(wheel.height), make_color(1., .1, 1.))

    // circle(pos.x, pos.y, radius, make_color(1., 0.1, 0.1))
    // circle(nextPos.x, nextPos.y, radius, make_color(0., 0.1, 1.))

    // for r in rects
    //     r |> draw()

    disable_alpha_blend()
