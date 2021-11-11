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
