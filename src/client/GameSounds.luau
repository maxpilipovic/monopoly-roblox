--!strict
-- Which sounds a game event makes, from this player's point of view: their own events are louder
-- than other players'. (No chime for your own turn.) Money changing hands (buying, paying, rent, collecting, passing GO, trading)
-- rings the cash register, except rent to an owner with a rent effect: the effect (and its own
-- sound) takes over. Pure, so it can be tested; GameClient plays the result at the event's moment.

local GameSounds = {}

export type Cue = { name: string, volume: number?, delay: number? }

local OTHERS = 0.55 -- other players' money, rung a little quieter

local function register(involvesMe: boolean): { Cue }
	return { { name = "Register", volume = if involvesMe then 1 else OTHERS } }
end

-- `rentEffects`: each player's equipped rent effect, if any (player id -> effect id).
function GameSounds.forEvent(event: { [string]: any }, localId: string, rentEffects: { [string]: string }?): { Cue }
	local kind = event.type
	local mine = event.player == localId
	local others = if mine then 1 else OTHERS
	if kind == "Rolled" and not event.forCard then
		return { { name = "Dice" } } -- doubles make no extra sound
	elseif kind == "Paid" then
		if event.reason == "Rent" and event.to and rentEffects and rentEffects[event.to] then
			return {} -- the owner's rent effect takes over
		end
		return register(event.from == localId or event.to == localId)
	elseif kind == "AuctionStarted" then
		return { { name = "Gavel" } }
	elseif kind == "BidPlaced" then
		return { { name = "Gavel", volume = 0.6 } }
	elseif kind == "BidPassed" then
		return if mine then { { name = "Tab" } } else {}
	elseif kind == "AuctionEnded" and event.winner then
		return { { name = "Sold" } } -- the payment that follows rings the register
	elseif kind == "Built" then
		return { { name = if event.hotel then "Hotel" else "Build", volume = others } }
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
		-- A trade with cash rings through its payments; this covers a straight property swap
		-- (GameSounds.dedupe keeps it to one ring).
		return register(event.to == localId or event.from == localId)
	elseif kind == "TradeDeclined" then
		return if event.from == localId then { { name = "Error", volume = 0.6 } } else {}
	elseif kind == "WentBankrupt" then
		return { { name = "Bankrupt", volume = others } }
	elseif kind == "GameOver" then
		return { { name = if event.winner == localId then "Win" else "Lose" } }
	end
	return {}
end

-- Drops a cue that would ring the cash register within `window` seconds of one already scheduled
-- (a purchase, a trade's two payments): one cha-ching per moment. `scheduled` is the times rung so
-- far; the cue's time is recorded when it's kept.
GameSounds.REGISTER_WINDOW = 0.4
function GameSounds.keep(cue: Cue, at: number, scheduled: { number }): boolean
	if cue.name ~= "Register" then
		return true
	end
	for _, other in scheduled do
		if math.abs(other - at) < GameSounds.REGISTER_WINDOW then
			return false
		end
	end
	table.insert(scheduled, at)
	return true
end

return GameSounds
