--!strict
-- The safe move played for a human whose turn timer ran out. It never spends their money by
-- choice: no buying, bidding or building. In debt it raises cash the way a bot would.

local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Timeouts = {}

local DEFAULTS = {
	Roll = "Roll", -- in jail this tries for doubles; the engine forces the fine after the third miss
	BuyDecision = "Decline",
	Auction = "PassBid",
	EndTurn = "EndTurn",
	Trade = "DeclineTrade",
}

function Timeouts.defaultAction(state: Types.GameState, playerId: string): Types.Action?
	if Engine.actingPlayer(state) ~= playerId then
		return nil
	end
	if state.phase == "Debt" then
		local me = Engine.getPlayer(state, playerId) :: Types.Player
		if me.money >= state.debts[1].amount then
			return { type = "PayDebt" }
		end
		return Bot.raiseCash(state, me) or { type = "Bankrupt" }
	end
	local default = DEFAULTS[state.phase]
	return if default then { type = default } else nil
end

return Timeouts
