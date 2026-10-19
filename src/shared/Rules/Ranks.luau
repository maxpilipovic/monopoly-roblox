--!strict
-- Ranked play's rating, chess style: everyone starts at 1000; the K-factor is high for your first
-- (provisional) games so you find your level fast, then settles, and is smallest at the top; and
-- ratings carry titles from Beginner to Grandmaster.

export type Title = { name: string, short: string, from: number, color: Color3 }

local Ranks = {}

Ranks.START = 1000
Ranks.PROVISIONAL_GAMES = 20

-- Lowest first; a rating takes the highest title whose `from` it reaches.
Ranks.TITLES = {
	{ name = "Beginner", short = "BEG", from = -math.huge, color = Color3.fromRGB(150, 160, 180) },
	{ name = "Novice", short = "NOV", from = 900, color = Color3.fromRGB(176, 186, 204) },
	{ name = "Intermediate", short = "INT", from = 1100, color = Color3.fromRGB(120, 200, 150) },
	{ name = "Advanced", short = "ADV", from = 1300, color = Color3.fromRGB(90, 180, 255) },
	{ name = "Expert", short = "EXP", from = 1500, color = Color3.fromRGB(130, 140, 255) },
	{ name = "Candidate Master", short = "CM", from = 1700, color = Color3.fromRGB(178, 102, 255) },
	{ name = "Master", short = "M", from = 1900, color = Color3.fromRGB(230, 110, 200) },
	{ name = "International Master", short = "IM", from = 2100, color = Color3.fromRGB(255, 150, 80) },
	{ name = "Grandmaster", short = "GM", from = 2300, color = Color3.fromRGB(255, 205, 80) },
} :: { Title }

function Ranks.titleFor(elo: number): Title
	local chosen = Ranks.TITLES[1]
	for _, title in Ranks.TITLES do
		if elo >= title.from then
			chosen = title
		end
	end
	return chosen
end

function Ranks.isProvisional(rankedGames: number): boolean
	return rankedGames < Ranks.PROVISIONAL_GAMES
end

-- How far one game moves this player's rating (FIDE-like).
function Ranks.kFactor(rankedGames: number, elo: number): number
	if Ranks.isProvisional(rankedGames) then
		return 40
	elseif elo >= 2100 then
		return 10
	end
	return 20
end

-- "1016 (+16)", "990 (−10)", "1000 (±0)".
function Ranks.changeText(elo: number, delta: number): string
	local sign = if delta > 0 then `+{delta}` elseif delta < 0 then `−{-delta}` else "±0"
	return `{math.floor(elo)} ({sign})`
end

return Ranks
