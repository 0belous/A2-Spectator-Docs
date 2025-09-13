--- Log a message to the console using the debug log level.
declare function debug(message: any): ()
--- Log a message to the console using the default log level.
declare function print(message: any): ()
--- Log a message to the console using the warning log level.
declare function warn(message: any): ()
--- Log a message to the console using the error log level. Unlike `error()` This won't raise an error.
declare function issue(message: any): ()

declare class Enum
	function GetEnumItems(self): { any }
end

declare class EnumItem
	Name: string
	Value: number
	EnumType: Enum
	function IsA(self, enumName: string): boolean
end

declare class EnumTextJustify extends EnumItem end
declare class EnumTextJustify_INTERNAL extends Enum
	Left: EnumTextJustify
	Center: EnumTextJustify
	Right: EnumTextJustify
end

type ENUM_LIST = {
	TextJustify: EnumTextJustify_INTERNAL
} & { GetEnumItems: (self: ENUM_LIST) -> { Enum } }
declare Enum: ENUM_LIST


declare class Vec3
	x: number
	y: number
	z: number
	function __mul (self, rhr: number): Vec3
	function __add (self, rhr: Vec3): Vec3
	function __sub (self, rhr: Vec3): Vec3
	function __div (self, rhr: number): Vec3
	function __unm (self, rhr: Vec3): Vec3
	function __len (self, rhr: Vec3): Vec3

	function __eq (self, rhr: Vec3): boolean
	function __tostring (self): string


	--- Dot product of two vectors
	function dot (self, rhr: Vec3): number
	--- Cross product of two vectors
	function cross (self, rhr: Vec3): Vec3

	--- Project self onto rhr
	function projectOnTo (self, rhr: Vec3): Vec3
	--- Magnitude of the vector
	function length (self): number
	--- Squared magnitude of the vector
	function squaredLength (self): number
	--- Creates a unit vector of length 1
	function normalize (self): Vec3
	--- Returns a unit length copy of the vector
	function getSafeNormal (self): Vec3
	--- Get the maximum value of the vector's components.
	function getMax (self): number
	--- Get the maximum absolute value of the vector's components.
	function getAbsMax(self): number
	--- Get the minimum value of the vector's components.
	function getMin(self): number
	--- Get the minimum absolute value of the vector's components.
	function getAbsMin(self): number
	--- Get a copy of this vector with absolute value of each component.
	function getAbs(self): Vec3
	--- Checks whether vector is near to zero within a reasonable tolerance.
	function isNearlyZero(self): boolean
	--- Checks whether all components of the vector are exactly zero.
	function isZero(self): boolean
	--- Checks whether vector is normalized.
	function isNormalized(self): boolean
	--- Get a copy of the vector as sign only. Each component is set to +1 or -1, with the sign of zero treated as +1.
	function getSignVector(self): Vec3
	--- Rotates around Axis (assumes Axis.Size() == 1).
	function rotateAngleAxis(self, degrees: number, axis: Vec3): Vec3
	--- Rotates around Axis (assumes Axis.Size() == 1).
	function rotateAngleAxisRad(self, radians: number, axis: Vec3): Vec3
	--- Utility to check if there are any non-finite values (NaN or Inf) in this vector.
	function containsNan(self): boolean
	--- Linearly interpolate between self and other by 0 <= t <= 1
	function lerp(self, other: Vec3, t: number): Vec3
	--- Distance between self and other
	function distance(self, other: Vec3): number
end

declare Vec3: {
	--- Construct a new vector (x,y,z)
	new: (x:number, y: number, z: number) -> Vec3,
	--- Calculate the dot product of two vectors.
	dot: (lhs: Vec3, rhs: Vec3) -> number,
	--- Calculate the cross product of two vectors.
	cross: (lhs: Vec3, rhs: Vec3) -> Vec3,
	--- Linearly interpolate between a and b by 0 <= t <= 1
	lerp: (a: Vec3, b: Vec3, t: number) -> Vec3,
	distance: (a: Vec3, b: Vec3) -> number,

	--- (0,0,1)
	upVector: Vec3,
	--- (0,0,-1)
	downVector: Vec3,
	--- (0,-1,0)
	leftVector: Vec3,
	--- (0,1,0)
	rightVector: Vec3,
	--- (1,0,0)
	forwardVector: Vec3,
	--- (-1,0,0)
	backwardVector: Vec3,
	--- (0,0,0)
	zeroVector: Vec3,
	--- (1,1,1)
	oneVector: Vec3,
	--- (0,0,1)
}

declare class Vec2
	x: number
	y: number
	function __add (self, rhr: Vec2): Vec2
	function __sub (self, rhr: Vec2): Vec2
	function __mul (self, rhr: number): Vec2
	function __div (self, rhr: number): Vec2
	function __unm (self, rhr: Vec2): Vec2
	function __len (self, rhr: Vec2): Vec2
	function __eq (self, rhr: Vec2): boolean
	function __tostring (self): string

	--- Dot product of two vectors
	function dot (self, rhr: Vec2): number

	--- Magnitude of the vector
	function length (self): number
	--- Squared magnitude of the vector
	function squaredLength (self): number
	--- Creates a unit vector of length 1
	function normalize (self): Vec2
	--- Returns a unit length copy of the vector
	function getSafeNormal (self): Vec2
	--- Get the maximum value of the vector's components.
	function getMax (self): number
	--- Get the maximum absolute value of the vector's components.
	function getAbsMax(self): number
	--- Get the minimum value of the vector's components.
	function getMin(self): number
	--- Get the minimum absolute value of the vector's components.
	function getAbsMin(self): number
	--- Get a copy of this vector with absolute value of each component.
	function getAbs(self): Vec2
	--- Checks whether vector is near to zero within a reasonable tolerance.
	function isNearlyZero(self): boolean
	--- Checks whether all components of the vector are exactly zero.
	function isZero(self): boolean
	--- Checks whether vector is normalized.
	function isNormalized(self): boolean
	--- Get a copy of the vector as sign only. Each component is set to +1 or -1, with the sign of zero treated as +1.
	function getSignVector(self): Vec2
	--- Utility to check if there are any non-finite values (NaN or Inf) in this vector.
	function containsNan(self): boolean
	--- Linearly interpolate between self and other by 0 <= t <= 1
	function lerp(self, other: Vec2, t: number): Vec2
	--- Distance between self and other
	function distance(self, other: Vec2): number
end

declare Vec2: {
	new: (x:number, y: number, z: number) -> Vec2,
	--- Zero vector (0,0)
	zeroVector: Vec2,
	--- One vector (1,1)
	oneVector: Vec2,
	--- Normalized one vector (sqrt(2),sqrt(2))
	unitDiagonal: Vec2,
	--- Unit X vector (1,0)
	unitX: Vec2,
	--- Unit Y vector (0,1)
	unitY: Vec2,

	--- Calculate the dot product of two vectors.
	dot: (lhs: Vec2, rhs: Vec2) -> number,

	--- Linearly interpolate between a and b by 0 <= t <= 1
	lerp: (a: Vec2, b: Vec2, t: number) -> Vec2,
	distance: (lhs: Vec2, rhs: Vec2) -> number,
	
	--- Construct a new vector (x,y)
	new: (x: number, y: number) -> Vec2,
}

declare class Quat
	x: number
	y: number
	z: number
	w: number
	function __mul (self, rhr: Quat): Quat
	function __eq (self, rhr: Quat): boolean
	function __tostring (self): string

	--- Convert a Quaternion into floating-point Euler angles (in degrees).
	function euler (self): Vec3
	--- Get the forward direction (X axis) after it has been rotated by this Quaternion.
	function getForwardVector (self): Vec3
	--- Get the right direction (Y axis) after it has been rotated by this Quaternion.
	function getRightVector (self): Vec3
	--- Get the up direction (Z axis) after it has been rotated by this Quaternion.
	function getUpVector (self): Vec3
	--- Rotate a vector by this quaternion.
	function rotateVector (self, vector: Vec3): Vec3
	function inverse (self): Quat
	--- Normalize this quaternion if it is large enough. If it is too small, returns an identity quaternion.
	function normalize (self): Quat
end

--- Quaternions
declare Quat: {
	--- Construct a new quaternion (x,y,z,w)
	new: (x: number, y: number, z: number, w: number) -> Quat,
	--- Convert a (roll, pitch, yaw) to a quaternion
	fromEuler: (roll: number, pitch: number, yaw: number) -> Quat,
	--- Create a quaternion from a foward direction, with global up as the reference up
	fromDirection: (direction: Vec3) -> Quat,
	--- Create a quaternion from foward and up vectors
	fromXZ: (forward: Vec3, up: Vec3) -> Quat,
	--- Find the smallest rotation between two vectors
	findBetweenVectors: (from: Vec3, to: Vec3) -> Quat,
	--- Spherical linear interpolation between a and b by 0 <= t <= 1
	slerp: (a: Quat, b: Quat, t: number) -> Quat,
	--- The identity quaternion, e.g. no rotation (0,0,0,1)
	identity: Quat
}

--- A 3D transformation
declare class Transform 
	position: Vec3
	rotation: Quat
	scale: Vec3
	__tostring: (self: Transform) -> string
end

declare Transform: {
	--- Create a new transform from a given position, rotation, and/or scale
	new: 
		((position: Vec3) -> Transform) | 
		(rotation: Quat) -> Transform |
		(position: Vec3, rotation: Quat) -> Transform |
		(position: Vec3, rotation: Quat, scale: Vec3) -> Transform,

	identity: Transform
}

declare class DateTime
	ticks: number
	__tostring: (self: DateTime) -> string
end

declare DateTime: {
	new: (ticks: number) -> DateTime,
	getCurrentTime: () -> DateTime
}

--- The config table from the configuation .json file
declare config: any


-- A simple LinearColor type which holds 4 Numbers
declare class LinearColor
	-- The X Component of the LinearColor
	R: number
	-- The Y Component of the LinearColor
	G: number
	-- The Z Component of the LinearColor
	B: number
	-- The A Component of the LinearColor
	A: number
	function __tostring (self): string
	function __mul (self, Rhs: LinearColor): LinearColor
end

declare class LinearColor_Class
	White: LinearColor
	new:
		((R: number, G: number, B: number, A: number) -> LinearColor) &
		({R: number?, G: number?, B: number?, A: number?}) -> LinearColor
end
declare LinearColor: LinearColor_Class