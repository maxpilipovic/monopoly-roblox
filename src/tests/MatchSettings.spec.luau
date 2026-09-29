--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["defaults are a relaxed timer and no length limit"] = function()
	Expect.equal(MatchSettings.DEFAULT.timer, "Relaxed")
	Expect.equal(MatchSettings.DEFAULT.length, "Off")
end

tests["validate keeps known ids and replaces anything else with the default"] = function()
	local chosen = MatchSettings.validate({ timer = "Fast", length = "Minutes30", seats = 4 })
	Expect.equal(chosen.timer, "Fast", "timer")
	Expect.equal(chosen.length, "Minutes30", "length")

	local fromNil = MatchSettings.validate(nil)
	Expect.equal(fromNil.timer, "Relaxed", "nil timer")
	Expect.equal(fromNil.length, "Off", "nil length")
	for i, raw in {
		5,
		"Fast",
		{},
		{ timer = 20, length = true },
		{ timer = "fast", length = "Rounds99" },
		{ timer = "__index", length = "" },
	} :: { any } do
		local settings = MatchSettings.validate(raw)
		Expect.equal(settings.timer, "Relaxed", `garbage #{i} timer`)
		Expect.equal(settings.length, "Off", `garbage #{i} length`)
	end
	assert(MatchSettings.validate(nil) ~= MatchSettings.DEFAULT, "must be a fresh table")
end

tests["cycling goes through every option in order and wraps round"] = function()
	local timers = { "Off" }
	for _ = 1, 3 do
		table.insert(timers, MatchSettings.nextTimer(timers[#timers]))
	end
	Expect.equal(table.concat(timers, ","), "Off,Relaxed,Fast,Off")

	local lengths = { "Off" }
	for _ = 1, 7 do
		table.insert(lengths, MatchSettings.nextLength(lengths[#lengths]))
	end
	Expect.equal(table.concat(lengths, ","), "Off,Rounds15,Rounds25,Rounds40,Minutes30,Minutes45,Minutes60,Off")
end

tests["seconds, limits and labels"] = function()
	Expect.equal(MatchSettings.timerSeconds({ timer = "Relaxed", length = "Off" }), 60, "relaxed")
	Expect.equal(MatchSettings.timerSeconds({ timer = "Fast", length = "Off" }), 20, "fast")
	Expect.equal(MatchSettings.timerSeconds({ timer = "Off", length = "Off" }), 0, "off")
	Expect.equal(MatchSettings.bidSeconds(60), 20, "relaxed bid")
	Expect.equal(MatchSettings.bidSeconds(20), 7, "fast bid")

	Expect.equal(MatchSettings.roundLimit({ timer = "Off", length = "Rounds25" }), 25, "rounds")
	Expect.equal(MatchSettings.roundLimit({ timer = "Off", length = "Minutes30" }), nil, "minutes has no round limit")
	Expect.equal(MatchSettings.limitMinutes({ timer = "Off", length = "Minutes45" }), 45, "minutes")
	Expect.equal(MatchSettings.limitMinutes({ timer = "Off", length = "Off" }), nil, "no limit")

	Expect.equal(MatchSettings.timerLabel("Relaxed"), "Timer: Relaxed 60 s")
	Expect.equal(MatchSettings.timerLabel("Fast"), "Timer: Fast 20 s")
	Expect.equal(MatchSettings.timerLabel("Off"), "Timer: Off")
	Expect.equal(MatchSettings.lengthLabel("Rounds25"), "Length: 25 rounds")
	Expect.equal(MatchSettings.lengthLabel("Minutes30"), "Length: 30 min")
	Expect.equal(MatchSettings.lengthLabel("Off"), "Length: Off")
end

return tests
