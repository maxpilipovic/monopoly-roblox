--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Dice = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Views.Dice)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a face has as many pips as its value, laid out symmetrically"] = function()
	for value = 1, 6 do
		local pips = Dice.pips(value)
		Expect.equal(#pips, value, `face {value}`)
		local seen = {}
		local centre = false
		for _, pip in pips do
			assert(pip.X >= 1 and pip.X <= 3 and pip.Y >= 1 and pip.Y <= 3, `face {value} pip off the grid`)
			seen[`{pip.X},{pip.Y}`] = true
			centre = centre or (pip.X == 2 and pip.Y == 2)
		end
		Expect.equal(centre, value % 2 == 1, `face {value} centre pip`)
		for _, pip in pips do
			assert(seen[`{4 - pip.X},{4 - pip.Y}`], `face {value} is not symmetric`)
		end
	end
end

tests["only faces one to six exist"] = function()
	for _, value in { 0, 7, 2.5 } do
		assert(not pcall(Dice.pips, value), `face {value} accepted`)
	end
end

local function pipCount(face: Instance): number
	local count = 0
	for _, child in face:GetChildren() do
		if child.Name == "Pip" then
			count += 1
		end
	end
	return count
end

tests["showing a roll draws both faces; no roll hides the dice"] = function()
	local holder = Instance.new("Frame")
	local dice = Dice.new(holder)
	dice:show(nil, false)
	Expect.equal(dice.frame.Visible, false, "nothing rolled yet")
	dice:show({ 3, 5 }, false)
	Expect.equal(dice.frame.Visible, true)
	Expect.equal(pipCount(dice.faces[1]), 3)
	Expect.equal(pipCount(dice.faces[2]), 5)
	dice:show({ 6, 1 }, false)
	Expect.equal(pipCount(dice.faces[1]), 6, "redrawn, not added to")
	Expect.equal(pipCount(dice.faces[2]), 1)
	holder:Destroy()
end

return tests
