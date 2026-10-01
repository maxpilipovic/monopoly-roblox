--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local HudView = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HudView)
local Ui = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Ui)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

-- Only the click-lock fields `send` reads; no GUI is built.
local function fakeHud(sent: { any })
	return {
		sentAt = nil,
		answered = true,
		callbacks = { onAction = function(action)
			table.insert(sent, action)
		end },
	} :: any
end

tests["send says whether the action went out, so callers don't act on a swallowed click"] = function()
	local sent = {}
	local hud = fakeHud(sent)
	Expect.equal(HudView.send(hud, { type = "Roll" }), true, "first click")
	Expect.equal(HudView.send(hud, { type = "Buy" }), false, "second half of a double-click")
	Expect.equal(#sent, 1, "only one action sent")
end

-- Builds a whole HUD in a scratch folder, runs the body, and always tears it down.
local function withHud(body: (hud: any) -> ())
	local holder = Instance.new("Folder")
	local hud = HudView.new(holder, {
		onAction = function() end,
		onStart = function() end,
		onReturnToLobby = function() end,
	})
	local ok, err = pcall(body, hud)
	hud:destroy()
	holder:Destroy()
	if not ok then
		error(err, 0)
	end
end

-- The action bar's buttons in display order, e.g. "Roll dice|Properties|Trade".
local function actions(hud: any): string
	local buttons = {}
	for _, child in hud.actionBar.buttons:GetChildren() do
		if child:IsA("TextButton") then
			table.insert(buttons, child)
		end
	end
	table.sort(buttons, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local texts = {}
	for _, button in buttons do
		table.insert(texts, button.Text)
	end
	return table.concat(texts, "|")
end

local function hasButton(root: Instance, text: string): boolean
	for _, child in root:GetDescendants() do
		if child:IsA("TextButton") and child.Text == text then
			return true
		end
	end
	return false
end

local function findButton(root: Instance, text: string): TextButton
	for _, child in root:GetDescendants() do
		if child:IsA("TextButton") and child.Text == text then
			return child
		end
	end
	error(`no "{text}" button`)
end

local function textOf(root: Instance, name: string): string
	local label = root:FindFirstChild(name, true)
	assert(label and label:IsA("TextLabel"), `no {name} label`)
	return label.Text
end

tests["the lobby offers seats, the three settings and Start"] = function()
	withHud(function(hud)
		hud:render(nil, "p1")
		Expect.equal(hud.lobby.frame.Visible, true, "lobby shown")
		for _, text in { "Start game", "-", "+", "Timer: Relaxed 60 s", "Length: Off", "Map: Classic" } do
			assert(hasButton(hud.lobby.frame, text), `no "{text}" button in the lobby`)
		end
		Expect.equal(hud.actionBar.frame.Visible, false, "no action bar in the lobby")
		Expect.equal(hud.playerList.frame.Visible, false, "no player list in the lobby")
	end)
end

tests["each phase shows its actions"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2, { { 2, 4 } })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.lobby.frame.Visible, false, "lobby hidden in a game")
		Expect.equal(hud.actionBar.frame.Visible, true)
		Expect.equal(hud.playerList.frame.Visible, true)
		Expect.equal(actions(hud), "Roll dice|Properties|Trade", "roll")
		Expect.equal(hud.actionBar.status.Text, "Your turn", "status")

		Engine.act(state, "p1", { type = "Roll" })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(actions(hud), "Buy for $100|Don't buy|Properties", "buy decision")

		Engine.act(state, "p1", { type = "Decline" })
		local auction = Snapshot.fromState(state)
		hud:render(auction, auction.acting :: string)
		assert(actions(hud):find("Pass", 1, true), `auction buttons: {actions(hud)}`)
		assert(not actions(hud):find("Properties", 1, true), "no Properties toggle in an auction")
	end)
end

tests["a debtor is offered a way to settle and the properties panel opens"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 1)
		GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(actions(hud), "Pay $200|Hide properties|Trade")
		Expect.equal(hud.propertiesPanel.frame.Visible, true, "raising cash happens in the panel")
		assert(hud.propertiesPanel.frame:FindFirstChild("Mediterranean Avenue", true), "the deed is listed")
	end)
end

tests["the receiver of a trade sees the offer with Accept and Decline"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(3)
		GameFixtures.own(state, "p2", 39)
		assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 100), GameFixtures.side({ 39 })))
		hud:render(Snapshot.fromState(state), "p2")
		Expect.equal(actions(hud), "Accept|Decline|Properties")
		Expect.equal(hud.offerCard.frame.Visible, true, "offer shown")
		Expect.equal(textOf(hud.offerCard.frame, "Title"), "Player 1 offers you a trade")
		assert(hud.offerCard.frame:FindFirstChild("Boardwalk", true), "the deed is shown as a chip")

		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.offerCard.frame.Visible, true, "the proposer sees it too")
		Expect.equal(textOf(hud.offerCard.frame, "Title"), "Your offer to Player 2")
		Expect.equal(actions(hud), "Properties", "but can only wait")

		hud:render(Snapshot.fromState(state), "p3")
		Expect.equal(textOf(hud.offerCard.frame, "Title"), "Player 1 offers Player 2 a trade")
		Expect.equal(actions(hud), "Properties", "a bystander only watches")
	end)
end

tests["game over shows the results and no actions"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(3)
		GameFixtures.own(state, "p3", 39)
		state.phase = "GameOver"
		state.winner = "p3"
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.results.frame.Visible, true, "results shown")
		Expect.equal(actions(hud), "", "no action buttons")
		assert(hasButton(hud.results.frame, "Back to lobby"), "a way back")
		assert(hud.results.frame:FindFirstChild("Rank1", true), "standings listed")
	end)
end

tests["back in the lobby every in-game screen is hidden and the log is empty"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 1)
		GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
		hud:render(Snapshot.fromState(state), "p1")
		hud:log({ "Player 1 rolled 3 + 4" })
		hud:notice("Not your turn")
		Expect.equal(#hud.logFeed.lines, 1, "the refusal is a toast, not a log line")
		Expect.equal(#hud.toasts.frame:GetChildren() > 1, true, "toast shown")

		hud:render(nil, "p1")
		Expect.equal(hud.lobby.frame.Visible, true)
		for _, name in { "actionBar", "playerList", "propertiesPanel", "tradeWindow", "offerCard", "results" } do
			Expect.equal(hud[name].frame.Visible, false, `{name} hidden`)
		end
		Expect.equal(#hud.logFeed.lines, 0, "log cleared")
	end)
end

tests["a spectator sees every phase without actions"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2, { { 2, 4 } })
		hud:render(Snapshot.fromState(state), "watcher")
		Expect.equal(actions(hud), "Properties", "only the view-only toggle")
		Engine.act(state, "p1", { type = "Roll" })
		hud:render(Snapshot.fromState(state), "watcher")
		Engine.act(state, "p1", { type = "Decline" })
		hud:render(Snapshot.fromState(state), "watcher")
		Expect.equal(actions(hud), "", "auction: nothing for a spectator")
		state.phase = "GameOver"
		hud:render(Snapshot.fromState(state), "watcher")
		Expect.equal(hud.results.frame.Visible, true)
	end)
end

tests["rendering the same snapshot again keeps the properties rows, so clicks and scroll survive"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 1)
		GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
		hud:render(Snapshot.fromState(state), "p1")
		local row = hud.propertiesPanel.frame:FindFirstChild("Mediterranean Avenue", true)
		assert(row, "row drawn")
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.propertiesPanel.frame:FindFirstChild("Mediterranean Avenue", true), row, "same instance")
	end)
end

tests["the trade window opens from the action bar and lists partners"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(3)
		hud:render(Snapshot.fromState(state), "p1")
		hud:toggleTrade()
		Expect.equal(hud.tradeWindow.frame.Visible, true)
		assert(hasButton(hud.tradeWindow.frame, "Player 2"), "partner 2")
		assert(hasButton(hud.tradeWindow.frame, "Player 3"), "partner 3")
		assert(hasButton(hud.tradeWindow.frame, "Send offer"), "send")
		Expect.equal(actions(hud), "Roll dice|Properties|Close trade")
		hud:toggleTrade()
		Expect.equal(hud.tradeWindow.frame.Visible, false)
	end)
end

tests["the HUD scales to the viewport, drops the log on narrow screens, and reports the bar's share"] = function()
	withHud(function(hud)
		hud:render(Snapshot.fromState(GameFixtures.newGame(2)), "p1")
		hud:applyViewport(Vector2.new(1280, 720))
		Expect.near(hud.rootScale.Scale, 1, "design size")
		Expect.equal(hud.logFeed.frame.Visible, true, "log on a wide screen")
		Expect.near(hud.gui:GetAttribute("BottomInset"), 124 / 720, "bar height plus margin")

		hud:applyViewport(Vector2.new(390, 844))
		Expect.near(hud.rootScale.Scale, 0.55, "phone")
		Expect.equal(hud.logFeed.frame.Visible, false, "no log on a narrow screen")
		hud:render(Snapshot.fromState(GameFixtures.newGame(2)), "p1")
		Expect.equal(hud.logFeed.frame.Visible, false, "a render doesn't bring it back")
		local inset = hud.gui:GetAttribute("BottomInset")
		assert(inset > 0 and inset <= 0.4, `inset {inset}`)
	end)
end

tests["buying and bidding show the tile's deed"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2, { { 2, 4 } })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.deedCard.frame.Visible, false, "nothing to decide yet")

		Engine.act(state, "p1", { type = "Roll" })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.deedCard.frame.Visible, true, "buy decision")
		Expect.equal(textOf(hud.deedCard.frame, "Name"), "Oriental Avenue")

		Engine.act(state, "p1", { type = "Decline" })
		local auction = Snapshot.fromState(state)
		hud:render(auction, auction.acting :: string)
		Expect.equal(hud.deedCard.frame.Visible, true, "auction")
		Expect.equal(textOf(hud.deedCard.frame, "Note"), "No bids yet")
		Engine.act(state, auction.acting :: string, { type = "Bid", amount = 20 })
		hud:render(Snapshot.fromState(state), "p1")
		assert(textOf(hud.deedCard.frame, "Note"):find("$20", 1, true), `bid note: {textOf(hud.deedCard.frame, "Note")}`)

		hud:render(nil, "p1")
		Expect.equal(hud.deedCard.frame.Visible, false, "lobby")
	end)
end

tests["a drawn card takes the centre until it is dismissed"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2, { { 2, 4 } })
		Engine.act(state, "p1", { type = "Roll" })
		hud:render(Snapshot.fromState(state), "p1")
		hud:showCard("chance.dividend", "Player 1", os.clock())
		hud:tick()
		Expect.equal(hud.cardReveal.frame.Visible, true, "card shown")
		Expect.equal(hud.deedCard.frame.Visible, false, "the deed waits behind the card")
		hud:dismissCard()
		hud:tick()
		Expect.equal(hud.cardReveal.frame.Visible, false, "dismissed")
		Expect.equal(hud.deedCard.frame.Visible, true, "the deed is back")

		hud:showCard("chest.go", "Player 2", os.clock())
		hud:tick()
		Expect.equal(hud.cardReveal.frame.Visible, true)
		hud:render(nil, "p1")
		hud:tick()
		Expect.equal(hud.cardReveal.frame.Visible, false, "the lobby drops cards")
	end)
end

tests["inspecting a property pins its deed until it is closed"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 39)
		hud:render(Snapshot.fromState(state), "p1")
		hud:inspect(39)
		Expect.equal(hud.deedCard.frame.Visible, true)
		Expect.equal(textOf(hud.deedCard.frame, "Name"), "Boardwalk")
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.deedCard.frame.Visible, true, "a render keeps it")
		hud:inspect(nil)
		Expect.equal(hud.deedCard.frame.Visible, false)
	end)
end

tests["the dice show the last roll and the status line doesn't repeat it"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2, { { 2, 4 } })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.actionBar.dice.frame.Visible, false, "nothing rolled yet")
		Engine.act(state, "p1", { type = "Roll" })
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.actionBar.dice.frame.Visible, true)
		Expect.equal(hud.actionBar.status.Text, "Your turn")
	end)
end

tests["properties are listed under their set with how much of it you own"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 1)
		GameFixtures.own(state, "p1", 5)
		hud:render(Snapshot.fromState(state), "p1")
		hud:toggleProperties()
		local panel = hud.propertiesPanel.frame
		Expect.equal(textOf(panel:FindFirstChild("Brown", true) :: Instance, "Title"), "Brown")
		Expect.equal(textOf(panel:FindFirstChild("Brown", true) :: Instance, "Owned"), "1/2")
		Expect.equal(textOf(panel:FindFirstChild("Railroads", true) :: Instance, "Owned"), "1/4")
		assert(panel:FindFirstChild("Mediterranean Avenue", true), "the street's row")
		assert(hasButton(panel, "Mortgage +$30"), "its action")
	end)
end

tests["the trade window shows deeds as chips and marks the ones picked"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		GameFixtures.own(state, "p1", 39)
		GameFixtures.own(state, "p2", 1)
		hud:render(Snapshot.fromState(state), "p1")
		hud:toggleTrade()
		local window = hud.tradeWindow.frame
		Ui.press(findButton(window, "Player 2"))
		assert(findButton(window, "Boardwalk"), "my deed")
		assert(findButton(window, "Mediterranean Avenue"), "their deed")
		Expect.equal(findButton(window, "Boardwalk"):GetAttribute("State"), "normal")
		Ui.press(findButton(window, "Boardwalk"))
		Expect.equal(findButton(hud.tradeWindow.frame, "Boardwalk"):GetAttribute("State"), "selected")
		Expect.equal(#hud.trade.give.properties, 1, "in the offer")
	end)
end

tests["the turn banner plays when the turn becomes yours, and only then"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		hud:render(Snapshot.fromState(state), "p2")
		Expect.equal(hud.turnBanner.frame.Visible, false, "someone else's turn")
		state.currentIndex = 2
		hud:render(Snapshot.fromState(state), "p2")
		Expect.equal(hud.turnBanner.frame.Visible, true, "now it's mine")
	end)
	withHud(function(hud)
		hud:render(Snapshot.fromState(GameFixtures.newGame(2)), "watcher")
		Expect.equal(hud.turnBanner.frame.Visible, false, "never for a spectator")
	end)
end

tests["a change in cash floats off the player's row"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.playerList.frame:FindFirstChild("Floater", true), nil, "a new game floats nothing")
		Engine.getPlayer(state, "p2").money = 1700
		hud:render(Snapshot.fromState(state), "p1")
		local floater = hud.playerList.frame:FindFirstChild("Floater", true)
		assert(floater and floater:IsA("TextLabel"), "floater shown")
		Expect.equal(floater.Text, "+$200")
	end)
end

tests["the timer bar drains with the turn and hides without a timer"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		hud:render(Snapshot.fromState(state), "p1")
		Expect.equal(hud.actionBar.timer.Visible, false, "no timer in play")
		local now = workspace:GetServerTimeNow()
		hud:render(Snapshot.fromState(state, { timer = "Fast", length = "Off", turnDeadline = now + 10 }), "p1")
		hud:tick()
		Expect.equal(hud.actionBar.timer.Visible, true)
		Expect.near(hud.actionBar.timer.Size.X.Scale, 0.5, "half the time left", 0.05)
	end)
end

tests["the winner gets confetti once"] = function()
	withHud(function(hud)
		local state = GameFixtures.newGame(2)
		state.phase = "GameOver"
		state.winner = "p1"
		hud:render(Snapshot.fromState(state), "p1")
		local function confetti(): number
			local count = 0
			for _, child in hud.results.confetti:GetChildren() do
				count += 1
			end
			return count
		end
		local first = confetti()
		assert(first > 0, "confetti thrown")
		hud:render(Snapshot.fromState(state), "p1")
		assert(confetti() <= first, "not thrown again on a re-render")
	end)
end

return tests
