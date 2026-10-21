--!strict
-- Which sounds a game event makes, from this player's point of view: their own events are louder
-- than other players'. Rent and paying out make no sound of their own (a rent effect is the show). Pure, so it can be tested; GameClient plays the result at the event's moment.

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
		-- Rent is marked by the owner's rent effect (which has its own sound), and paying out is silent.
		if event.reason == "Go" then
			return { { name = "PassGo", volume = if event.to == localId then 1 else 0.5 } }
		elseif event.reason ~= "Rent" and event.to == localId then
			return { { name = "Coins" } }
		end
		return {}
	elseif kind == "FreeParkingPaid" then
		return { { name = "Coins", volume = others } }
	elseif kind == "Bought" then
		-- A purchase rings up like a cash register: cha-ching.
		return { { name = "PassGo", volume = others } }
	elseif kind == "AuctionStarted" then
		return { { name = "Gavel" } }
	elseif kind == "BidPlaced" then
		return { { name = "Gavel", volume = 0.6 } }
	elseif kind == "BidPassed" then
		return if mine then { { name = "Tab" } } else {}
	elseif kind == "AuctionEnded" and event.winner then
		-- The gavel, and a cha-ching for whoever won it.
		local cues: { Cue } = { { name = "Sold" } }
		if event.winner == localId then
			table.insert(cues, { name = "PassGo", delay = 0.5 })
		end
		return cues
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
	elseif kind == "LeftJail" then
		return { { name = "Unlock", volume = others } }
	elseif kind == "OfferedPurchase" then
		return if mine then { { name = "Notify", volume = 0.7 } } else {}
	elseif kind == "PurchaseDeclined" then
		return if mine then { { name = "Close" } } else {}
	elseif kind == "DebtOwed" then
		return if event.debtor == localId then { { name = "Alert" } } else {}
	elseif kind == "PlayerReplaced" then
		return { { name = "Close", volume = 0.6 } }
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
