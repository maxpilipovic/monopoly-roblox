--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Layout = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Layout)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["the HUD scales to the smaller axis, within limits"] = function()
	Expect.near(Layout.scale(Vector2.new(1280, 720)), 1, "design size")
	Expect.near(Layout.scale(Vector2.new(1736, 793)), 793 / 720, "limited by height")
	Expect.near(Layout.scale(Vector2.new(1000, 2000)), 1000 / 1280, "limited by width")
	Expect.near(Layout.scale(Vector2.new(3840, 2160)), 1.3, "capped on large screens")
	Expect.near(Layout.scale(Vector2.new(390, 844)), 0.55, "floored on a portrait phone")
	Expect.near(Layout.scale(Vector2.new(0, 0)), 0.55, "no viewport yet")
end

tests["only narrow screens use the narrow layout"] = function()
	Expect.equal(Layout.isNarrow(Vector2.new(390, 844)), true, "portrait phone")
	Expect.equal(Layout.isNarrow(Vector2.new(1280, 720)), false, "design size")
	Expect.equal(Layout.isNarrow(Vector2.new(844, 390)), false, "landscape phone")
	Expect.equal(Layout.isNarrow(Vector2.new(1736, 793)), false, "desktop")
end

tests["the bottom inset is the share of the screen the action bar covers"] = function()
	Expect.near(Layout.bottomInset(100, 12, 1, 720), 112 / 720, "design size")
	Expect.near(Layout.bottomInset(100, 12, 0.55, 390), 112 * 0.55 / 390, "landscape phone")
	Expect.near(Layout.bottomInset(400, 12, 1.3, 600), 0.4, "clamped")
	Expect.near(Layout.bottomInset(100, 12, 1, 0), 0, "no viewport yet")
end

return tests
