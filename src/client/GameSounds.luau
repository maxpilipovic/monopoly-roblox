--!strict
-- Which sounds a game event makes, from this player's point of view: their own money and moves are
-- loud and specific (rent coming in is a coin cascade, paying out a few coins dropping), other
-- players' quieter. Pure, so it can be tested; GameClient plays the result at the event's moment.

local GameSounds = {}

export type Cue = { name: string, volume: number?, delay: number? }

local DICE_SETTLE = 1.25 -- seconds from the throw until the dice come to rest

function GameSounds.forEvent(event: { [string]: any }, localId: string): { Cue }
	local kind = event.type
	local mine = event.player == localId
	local others = if mine then 1 else 0.55
	if kind == "Rolled" and not event.forCard then
		local cues: { Cue } = { { name = "Dice" } }
		if event.dice[1] == event.dice[2] then
			table.insert(cues, { name = "Doubles", delay = DICE_SETTLE })
		end
		return cues
	elseif kind == "Paid" then
		if event.reason == "Go" then
			return { { name = "PassGo", volume = if event.to == localId then 1 else 0.5 } }
		elseif event.to == localId then
			return { { name = "Coins" } }
		elseif event.from == localId then
			return { { name = "Pay" } }
		end
		return { { name = "Coin", volume = 0.45 } }
	elseif kind == "FreeParkingPaid" then
		return { { name = "Coins", volume = others } }
	elseif kind == "Bought" then
		return { { name = "Buy", volume = others } }
	elseif kind == "BidPlaced" then
		return { { name = "Gavel", volume = 0.6 } }
	elseif kind == "AuctionEnded" and event.winner then
		return { { name = "Sold" } }
	elseif kind == "Built" then
		return { { name = if event.hotel then "Hotel" else "Build", volume = others } }
	elseif kind == "BuildingSold" or kind == "Unmortgaged" then
		return { { name = "Coin", volume = others } }
	elseif kind == "Mortgaged" then
		return { { name = "Mortgage", volume = others } }
	elseif kind == "CardDrawn" then
		return { { name = "Card" } }
	elseif kind == "SentToJail" then
		return { { name = "Jail" } }
	elseif kind == "TradeProposed" then
		return if event.to == localId or event.from == localId then { { name = "Notify" } } else {}
	elseif kind == "TradeAccepted" then
		return { { name = "TradeDone", volume = if event.to == localId or event.from == localId then 1 else 0.5 } }
	elseif kind == "TradeDeclined" then
		return if event.from == localId then { { name = "Error", volume = 0.6 } } else {}
	elseif kind == "WentBankrupt" then
		return { { name = "Bankrupt", volume = others } }
	elseif kind == "GameOver" then
		return { { name = if event.winner == localId then "Win" else "Lose" } }
	elseif kind == "TurnStarted" and mine then
		return { { name = "YourTurn" } }
	end
	return {}
end

return GameSounds
