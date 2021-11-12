require daslib/media

require math_utils

struct Contact
    pos: float2
    normal: float2
    depth: float

struct RoadContact
    contact: Contact
    center: float2
    t: float

struct Spring
    from: float2
    to: float2

    dir: float2

    length: float
    curLength: float
    wishLength: float

let INVALID_CONTACT = [[Contact pos=float2(), normal=float2(), depth=-1.]]

struct Projectile
    pos: float2
    vel: float2
    damage: float
    ttl: float

def Projectile()
    return [[Projectile damage=1., ttl=1.]]

[generic]
def integrate(var arr; dt: float)
    for item in arr
        item.pos += item.vel * dt

[generic]
def erase_by_ttl(var arr)
    var i = length(arr)
    while --i >= 0
        if arr[i].ttl <= 0.
            arr |> erase(i)

[generic]
def erase_by_offscreen(var arr)
    let screenSize = float2(get_screen_width(), get_screen_height())
    var i = length(arr)
    while --i >= 0
        let p = arr[i].pos
        if p.x <= 0. || p.y < 0. || p.x >= screenSize.x || p.y >= screenSize.y
            arr |> erase(i)
