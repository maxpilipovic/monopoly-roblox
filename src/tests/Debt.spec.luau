--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local PAY = { type = "PayDebt" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 has $3 and rolls onto p2's Oriental Avenue ($6 rent).
local function shortOnRent()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	player(state, "p1").money = 3
	act(state, "p1", ROLL)
	return state
end

-- p1 is in jail with $20 on their third try; the roll {1, 2} forces the $50 fine and moves them to 13.
local function forcedFine(playerCount: number?)
	local state = GameFixtures.newGame(playerCount or 2, { { 1, 2 } })
	local p1 = player(state, "p1")
	p1.position = Engine.JAIL_POSITION
	p1.inJail = true
	p1.jailAttempts = 2
	p1.money = 20
	return state
end

tests["rent you can't afford becomes a debt and pauses the game on you"] = function()
	local state = shortOnRent()
	Expect.equal(player(state, "p1").money, 3, "nothing taken")
	Expect.equal(player(state, "p2").money, 1500, "creditor not paid yet")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.resumePhase, "EndTurn")
	Expect.equal(Engine.actingPlayer(state), "p1")
	local debt = state.debts[1]
	Expect.equal(debt.debtor, "p1", "debtor")
	Expect.equal(debt.creditor, "p2", "creditor")
	Expect.equal(debt.amount, 6, "amount")
	Expect.equal(debt.reason, "Rent", "reason")
	local owed = GameFixtures.eventsOfType(state, "DebtOwed")[1]
	Expect.equal(owed.creditor, "p2", "event creditor")
	Expect.equal(owed.amount, 6, "event amount")
end

tests["paying the debt pays the creditor and resumes the turn"] = function()
	local state = shortOnRent()
	player(state, "p1").money = 10
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 4, "p1")
	Expect.equal(player(state, "p2").money, 1506, "p2")
	Expect.equal(#state.debts, 0, "debts")
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(state.resumePhase, nil, "resume cleared")
	local paid = GameFixtures.eventsOfType(state, "DebtPaid")[1]
	Expect.equal(paid.creditor, "p2", "event creditor")
	local rent = GameFixtures.eventsOfType(state, "Paid")
	Expect.equal(rent[#rent].reason, "Rent", "paid as rent")
end

tests["PayDebt is refused while you are short"] = function()
	local state = shortOnRent()
	local ok, err = Engine.act(state, "p1", PAY)
	assert(not ok, "paid without the money")
	Expect.equal(err, "not enough money")
	Expect.equal(#state.debts, 1, "still owed")
	Expect.equal(state.phase, "Debt")
end

tests["in debt you may only sell buildings, mortgage, or pay"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3, 1)
	GameFixtures.own(state, "p1", 15)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	player(state, "p1").money = 3
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Debt")
	for _, action in {
		{ type = "EndTurn" },
		{ type = "Roll" },
		{ type = "Build", position = 1 },
		{ type = "Unmortgage", position = 5 },
		{ type = "Buy" },
	} :: { any } do
		local ok, err = Engine.act(state, "p1", action)
		assert(not ok, `{action.type} allowed in debt`)
		Expect.equal(err, "pay your debt first", action.type)
	end
	act(state, "p1", { type = "SellBuilding", position = 1 })
	Expect.equal(player(state, "p1").money, 28, "sold a house")
	act(state, "p1", { type = "Mortgage", position = 15 })
	Expect.equal(player(state, "p1").money, 128, "mortgaged")
	Expect.equal(state.phase, "Debt", "still in debt until paid")
	act(state, "p1", PAY)
	Expect.equal(state.phase, "EndTurn")
end

tests["only the debtor acts during a debt"] = function()
	local state = shortOnRent()
	for _, action in { PAY, { type = "Mortgage", position = 6 }, { type = "EndTurn" } } :: { any } do
		local ok, err = Engine.act(state, "p2", action)
		assert(not ok, `p2 {action.type} accepted`)
		Expect.equal(err, "waiting for another player to pay a debt", action.type)
	end
	Expect.equal(state.properties[6].mortgaged, false, "p2's deed untouched")
end

tests["debt actions outside a debt are refused"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	assert(not Engine.act(state, "p1", PAY), "PayDebt in Roll")
	assert(not Engine.act(state, "p1", { type = "Bankrupt" }), "Bankrupt in Roll")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.events, 1, "only TurnStarted")
end

tests["a debt raised mid-move keeps the buy decision for after"] = function()
	local state = forcedFine()
	act(state, "p1", ROLL) -- fine becomes a debt, then lands on unowned States Avenue
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 13, "still moved")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.resumePhase, "BuyDecision")
	p1.money = 300
	act(state, "p1", PAY)
	Expect.equal(p1.money, 250, "fine paid")
	Expect.equal(state.phase, "BuyDecision", "purchase still offered")
end

tests["once in debt, later charges queue behind it even if affordable"] = function()
	local state = forcedFine()
	GameFixtures.own(state, "p2", 13) -- $10 rent, and p1 still has $20
	act(state, "p1", ROLL)
	Expect.equal(#state.debts, 2, "fine and rent both owed")
	Expect.equal(state.debts[1].reason, "JailFine", "fine first")
	Expect.equal(state.debts[2].reason, "Rent", "rent second")
	Expect.equal(player(state, "p1").money, 20, "nothing paid out of order")
	player(state, "p1").money = 100
	act(state, "p1", PAY)
	Expect.equal(state.phase, "Debt", "rent still owed")
	Expect.equal(Engine.actingPlayer(state), "p1")
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 40, "paid both")
	Expect.equal(player(state, "p2").money, 1510, "rent reached p2")
	Expect.equal(state.phase, "EndTurn")
end

tests["pay each player: pays whom it can, owes the rest, in seat order"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 4
	player(state, "p1").money = 60
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 10, "paid p2")
	Expect.equal(player(state, "p2").money, 1550, "p2")
	Expect.equal(#state.debts, 1, "owes p3")
	Expect.equal(state.debts[1].creditor, "p3", "creditor")
	Expect.equal(state.debts[1].amount, 50, "amount")
end

tests["collect from each player puts each short player in debt, in seat order"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 14
	player(state, "p2").money = 5
	player(state, "p3").money = 5
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.birthday" })
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Debt")
	Expect.equal(Engine.actingPlayer(state), "p2", "p2 first")
	assert(not Engine.act(state, "p1", { type = "EndTurn" }), "drawer moved on early")
	player(state, "p2").money = 20
	act(state, "p2", PAY)
	Expect.equal(Engine.actingPlayer(state), "p3", "then p3")
	player(state, "p3").money = 20
	act(state, "p3", PAY)
	Expect.equal(state.phase, "EndTurn", "back to the drawer's turn")
	Expect.equal(Engine.actingPlayer(state), "p1")
	Expect.equal(player(state, "p1").money, 1520, "collected from both")
end

tests["a debt to a player who has since gone bankrupt is paid to the bank"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.inDebt(state, "p1", 50, "p2", "Rent")
	player(state, "p2").bankrupt = true
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 1450, "p1 paid")
	Expect.equal(player(state, "p2").money, 1500, "bankrupt p2 not paid")
	local paid = GameFixtures.eventsOfType(state, "Paid")
	Expect.equal(paid[#paid].to, nil, "paid to the bank")
end

return tests
