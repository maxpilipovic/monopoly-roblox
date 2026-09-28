--!strict
local Expect = {}

function Expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Expect.near(actual: number, expected: number, label: string?, epsilon: number?)
	if math.abs(actual - expected) > (epsilon or 1e-3) then
		error(`{label or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

function Expect.vectorNear(actual: Vector3, expected: Vector3, label: string?, epsilon: number?)
	if (actual - expected).Magnitude > (epsilon or 1e-3) then
		error(`{label or "vector"}: expected {expected}, got {actual}`, 2)
	end
end

return Expect
