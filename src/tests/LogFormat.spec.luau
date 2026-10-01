--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local LogFormat = require(StarterPlayer.StarterPlayerScripts.Client.Hud.LogFormat)
local Expect = require(script.Parent.Expect)

local tests = {}

local function colored(name: string, seat: number): string
	return `<font color="#{TokenLayout.SEAT_COLORS[seat]:ToHex()}">{name}</font>`
end

tests["player names take their seat colour"] = function()
	local players = { { name = "Ana", seat = 1 }, { name = "Bot 1", seat = 2 } }
	Expect.equal(
		LogFormat.rich("Ana paid $10 rent to Bot 1", players),
		`{colored("Ana", 1)} paid $10 rent to {colored("Bot 1", 2)}`
	)
end

tests["rich-text characters in names and lines are shown literally"] = function()
	local players = { { name = "<b>Max</b>", seat = 1 } }
	Expect.equal(LogFormat.escape(`a < b & "c" > 'd'`), "a &lt; b &amp; &quot;c&quot; &gt; &apos;d&apos;")
	Expect.equal(
		LogFormat.rich("<b>Max</b> rolled 3 + 4", players),
		`{colored("&lt;b&gt;Max&lt;/b&gt;", 1)} rolled 3 + 4`
	)
end

tests["a longer name is not split by a shorter one inside it"] = function()
	local players = { { name = "Bot 1", seat = 2 }, { name = "Bot 10", seat = 3 } }
	Expect.equal(LogFormat.rich("Bot 10 passed", players), `{colored("Bot 10", 3)} passed`)
	Expect.equal(LogFormat.rich("Bot 1 passed", players), `{colored("Bot 1", 2)} passed`)
end

tests["a line without names is only escaped"] = function()
	Expect.equal(LogFormat.rich("Auction for B. & O. Railroad", { { name = "Ana", seat = 1 } }), "Auction for B. &amp; O. Railroad")
end

return tests
