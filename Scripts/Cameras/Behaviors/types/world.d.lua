declare WorldDraw: {
    --- Draws a line in space, color values are from 0-1, lifetime of 0 means it will not be cleared
    drawLine: (startPos: Vec3, endPos: Vec3, r: number, g: number, b: number, thickness: number, lifetime: number)-> (),
    --- Draws a point in space, color values are from 0-1, lifetime of 0 means it will not be cleared
    drawPoint: (position: Vec3, r: number, g: number, b: number, pointSize: number, lifetime: number)-> (),
    --- Draws a triangle in space, color values are from 0-1, lifetime of 0 means it will not be cleared. This triangle is one-sided, so the order of the points matters.
    drawTriangle: (point1: Vec3, point2: Vec3, point3: Vec3, color: Vec3, lifetime: number)-> (),
    --- Clears all existing lines and points
    clear:()-> (),
    --- Clears all existing lines, points, and lights
    clearAll:()-> (),
    clearLights:()-> (),
    --- Returns nil if the light failed to spawn
    spawnPointLight:(position:Vec3, intensity: number, color: Vec3, radius: number) -> LuauPointLight?
}

declare class LuauPointLight
    position: Vec3
    --- The brightness of the light
    intensity: number
    --- The RGB color of the light, values are from 0-1
    color: Vec3
    --- The range of the light in world units. This is the distance at which the light's intensity will be reduced to 0.
    radius: number
    function destroy(self): ()
end
