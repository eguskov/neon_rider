require dasbib/media

require math

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

def hermit_interp(from, to, m0, m1, t: float)
    let t2 = t * t
    let t3 = t2 * t
    return (2. * t3 - 3. * t2 + 1.) * from + (t3 - 2. * t2 + t) * m0 + (-2. * t3 + 3. * t2) * to + (t3 - t2) * m1

def make_tm(angle: float)
    let c = cos(angle)
    let s = sin(angle)
    return float4(c, -s, s, c)

def inverse(tm: float4)
    return float4(tm.x, tm.z, tm.y, tm.w)

def rotate(tm: float4; p: float2)
    return float2(dot(tm.xy, p), dot(tm.zw, p))

def approach(from, to; dt, viscosity: float)
    return viscosity > 1e-9 ? from + (1. - exp(-dt / viscosity)) * (to - from) : to

def in_box(box: float4; p: float2)
    return (p.x >= box.y && p.y >= box.y &&
            p.x <= box.z && p.y <= box.w)

var rnd_seed = random_seed(int(get_time_after_start()))
def rnd_range(x, y: float)
    let r = random_float(rnd_seed)
    return x + (y - x) * r

def rnd_range(r: float2)
    return rnd_range(r.x, r.y)

def rnd_range(r: int2)
    return roundi(rnd_range(float(r.x), float(r.y)))

def rnd_range(r: float3[2])
    return float3(rnd_range(r[0].x, r[1].x), rnd_range(r[0].y, r[1].y), rnd_range(r[0].z, r[1].z))
