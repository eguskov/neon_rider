require utils

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

    // Debug
    frontTraceFrom: float2
    frontTraceTo: float2
