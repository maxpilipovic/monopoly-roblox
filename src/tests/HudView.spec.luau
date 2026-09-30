--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local HudView = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HudView)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Only the click-lock fields `send` reads; no GUI is built.
local function fakeHud(sent: { any })
	return {
		sentAt = nil,
		answered = true,
		callbacks = { onAction = function(action)
			table.insert(sent, action)
		end },
	} :: any
end

tests["send says whether the action went out, so callers don't act on a swallowed click"] = function()
	local sent = {}
	local hud = fakeHud(sent)
	Expect.equal(HudView.send(hud, { type = "Roll" }), true, "first click")
	Expect.equal(HudView.send(hud, { type = "Buy" }), false, "second half of a double-click")
	Expect.equal(#sent, 1, "only one action sent")
end

return tests
