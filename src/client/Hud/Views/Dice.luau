--!strict
-- The last roll as two drawn dice; they tumble when a new roll arrives.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local Dice = {}
Dice.__index = Dice

local FACE_SIZE = 34
local PIP_SIZE = 7
local TUMBLE_STEPS = 10 -- ~0.7 s: settles before the token sets off (Pacing.DICE_SECONDS)
local TUMBLE_STEP_SECONDS = 0.07

-- Pip centres on a 3 x 3 grid (1 = left/top, 3 = right/bottom).
local PIPS: { { Vector2 } } = {
	{ Vector2.new(2, 2) },
	{ Vector2.new(1, 1), Vector2.new(3, 3) },
	{ Vector2.new(1, 1), Vector2.new(2, 2), Vector2.new(3, 3) },
	{ Vector2.new(1, 1), Vector2.new(3, 1), Vector2.new(1, 3), Vector2.new(3, 3) },
	{ Vector2.new(1, 1), Vector2.new(3, 1), Vector2.new(2, 2), Vector2.new(1, 3), Vector2.new(3, 3) },
	{ Vector2.new(1, 1), Vector2.new(3, 1), Vector2.new(1, 2), Vector2.new(3, 2), Vector2.new(1, 3), Vector2.new(3, 3) },
}

export type Dice = typeof(setmetatable({} :: { frame: Frame, faces: { Frame }, generation: number }, Dice))

function Dice.pips(value: number): { Vector2 }
	return assert(PIPS[value], `a die has no face {value}`)
end

local function draw(face: Frame, value: number)
	for _, child in face:GetChildren() do
		if child.Name == "Pip" then
			child:Destroy()
		end
	end
	for _, pip in Dice.pips(value) do
		local dot = Instance.new("Frame")
		dot.Name = "Pip"
		dot.Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(pip.X * 0.25, pip.Y * 0.25)
		dot.BackgroundColor3 = Theme.color.ink
		dot.BorderSizePixel = 0
		dot.Parent = face
		Ui.corner(dot, PIP_SIZE)
	end
end

function Dice.new(parent: Instance): Dice
	local frame = Ui.frame("Dice", UDim2.fromOffset(2 * FACE_SIZE + 6, FACE_SIZE), parent)
	frame.Visible = false
	local faces = {}
	for index = 1, 2 do
		local face = Instance.new("Frame")
		face.Name = `Die{index}`
		face.Size = UDim2.fromOffset(FACE_SIZE, FACE_SIZE)
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromOffset(FACE_SIZE / 2 + (index - 1) * (FACE_SIZE + 6), FACE_SIZE / 2)
		face.BackgroundColor3 = Theme.color.paper
		face.BorderSizePixel = 0
		face.Parent = frame
		Ui.corner(face, 7)
		table.insert(faces, face)
	end
	return setmetatable({ frame = frame, faces = faces, generation = 0 }, Dice)
end

-- Shows a roll (nil hides the dice). With `tumble`, the faces spin through a few values first.
function Dice.show(self: Dice, roll: { number }?, tumble: boolean)
	self.generation += 1
	local generation = self.generation
	self.frame.Visible = roll ~= nil
	if not roll then
		return
	end
	local function settle()
		for index, face in self.faces do
			face.Rotation = 0
			draw(face, roll[index])
		end
	end
	if not tumble then
		settle()
		return
	end
	task.spawn(function()
		for _ = 1, TUMBLE_STEPS do
			if self.generation ~= generation or not self.frame.Parent then
				return -- a newer roll (or the lobby) took over
			end
			for _, face in self.faces do
				face.Rotation = math.random(-18, 18)
				draw(face, math.random(1, 6))
			end
			task.wait(TUMBLE_STEP_SECONDS)
		end
		if self.generation == generation and self.frame.Parent then
			settle()
		end
	end)
end

return Dice
