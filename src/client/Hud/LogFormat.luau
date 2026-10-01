--!strict
-- Turns a plain log line into rich text: player names in their seat colours, everything else literal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)

local LogFormat = {}

local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

function LogFormat.escape(text: string): string
	return (text:gsub("[&<>\"']", ESCAPES))
end

function LogFormat.rich(line: string, players: { { name: string, seat: number } }): string
	-- Longest names first, so "Bot 1" doesn't claim the start of "Bot 10".
	local byLength = table.clone(players)
	table.sort(byLength, function(a, b)
		return #a.name > #b.name
	end)

	local out = {}
	local index = 1
	local plainFrom = 1
	while index <= #line do
		local matched = nil
		for _, player in byLength do
			if #player.name > 0 and line:sub(index, index + #player.name - 1) == player.name then
				matched = player
				break
			end
		end
		if matched then
			table.insert(out, LogFormat.escape(line:sub(plainFrom, index - 1)))
			local color = TokenLayout.SEAT_COLORS[matched.seat]
			local hex = if color then color:ToHex() else "ffffff"
			table.insert(out, `<font color="#{hex}">{LogFormat.escape(matched.name)}</font>`)
			index += #matched.name
			plainFrom = index
		else
			index += 1
		end
	end
	table.insert(out, LogFormat.escape(line:sub(plainFrom)))
	return table.concat(out)
end

return LogFormat
