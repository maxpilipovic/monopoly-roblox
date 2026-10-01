--!strict
-- The trade window: pick a partner, put deeds, cash and jail cards on each side, send the offer.
-- TradeBuilder holds the working offer and TradeRules says whether it may be sent; this only draws it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TradeBuilder = require(script.Parent.Parent.TradeBuilder)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TradeWindow = {}
TradeWindow.__index = TradeWindow

local CASH_STEPS = { -100, -50, -10, 10, 50, 100 }

export type Hooks = {
	send: (action: { [string]: any }) -> boolean, -- whether the offer went out
	close: () -> (), -- the window should close and the draft be dropped
	changed: () -> (), -- the draft changed: draw it again
}

export type TradeWindow = typeof(setmetatable({} :: { frame: Frame, hooks: Hooks, key: string? }, TradeWindow))

function TradeWindow.new(parent: Instance, hooks: Hooks): TradeWindow
	local frame = Ui.panel("Trade", UDim2.fromOffset(680, 440), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), parent)
	frame.Visible = false
	return setmetatable({ frame = frame, hooks = hooks, key = nil }, TradeWindow)
end

function TradeWindow.render(
	self: TradeWindow,
	open: boolean,
	snapshot: Protocol.Snapshot,
	localId: string,
	builder: TradeBuilder.Builder
)
	local window = self.frame
	Ui.setVisible(window, open)
	TradeBuilder.prune(builder, snapshot, localId)
	local ok, reason = TradeBuilder.check(snapshot, localId, builder)
	local holdings = {}
	for _, player in snapshot.players do
		holdings[player.id] = { player.money, player.jailCards }
	end
	-- Rebuild only when something shown changed, so bot moves don't reset the scroll or eat clicks.
	local key = HttpService:JSONEncode({
		open = open,
		partners = TradeBuilder.partners(snapshot, localId),
		builder = builder,
		give = TradeBuilder.rows(snapshot, localId, builder.give),
		get = if builder.partner then TradeBuilder.rows(snapshot, builder.partner, builder.get) else {},
		ok = ok,
		reason = reason,
		holdings = holdings,
	})
	if key == self.key then
		return
	end
	self.key = key
	Ui.clear(window)
	if not open then
		return
	end
	local changed = self.hooks.changed

	-- Partner picker across the top.
	local partnerRow = Ui.frame("Partners", UDim2.new(1, -24, 0, 40), window)
	partnerRow.Position = UDim2.fromOffset(12, 12)
	Ui.list(partnerRow, Enum.FillDirection.Horizontal, 6)
	for order, partner in TradeBuilder.partners(snapshot, localId) do
		local picked = builder.partner == partner.id
		local button = Ui.button(partner.name, partnerRow, function()
			TradeBuilder.setPartner(builder, partner.id)
			changed()
		end, if picked then "accent" else "secondary")
		button.Size = UDim2.fromOffset(124, 36)
		button.LayoutOrder = order
		Ui.setTextSize(button, 15)
	end

	local players = {}
	for _, player in snapshot.players do
		players[player.id] = player
	end

	-- One column per side: deeds, then cash and jail-card steppers.
	local function column(sideName: TradeBuilder.SideName, ownerId: string?, x: number)
		local surface = Ui.surface(sideName, UDim2.new(0.5, -18, 1, -124), window)
		surface.Position = UDim2.new(x, if x == 0 then 12 else 6, 0, 60)
		local frame = Instance.new("ScrollingFrame")
		frame.Name = "Rows"
		frame.Size = UDim2.new(1, -12, 1, -12)
		frame.Position = UDim2.fromOffset(8, 6)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ScrollBarThickness = 6
		frame.ScrollBarImageColor3 = Theme.color.textDim
		frame.CanvasSize = UDim2.new()
		frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		frame.Parent = surface
		Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)

		local title = Ui.label("Title", frame, UDim2.new(1, -8, 0, 26), 18, Theme.font.display)
		title.Text = if sideName == "give" then "You give" else "You get"
		title.TextColor3 = Theme.color.accent
		if not ownerId then
			return
		end
		local owner = players[ownerId]
		local side = builder[sideName]
		for order, row in TradeBuilder.rows(snapshot, ownerId, side) do
			local name = if row.mortgaged then `{row.name} (mortgaged)` else row.name
			local label = if row.tradable then name else `{name} — {row.reason}`
			local style: Ui.Style = if row.selected then "primary" elseif not row.tradable then "disabled" else "secondary"
			local button = Ui.button(label, frame, function()
				if TradeBuilder.canToggle(row) then
					TradeBuilder.toggle(builder, sideName, row.position)
					changed()
				end
			end, style)
			button.Size = UDim2.new(1, -8, 0, 32)
			button.LayoutOrder = order
			Ui.setTextSize(button, 14)
		end

		local cashRow = Ui.frame("Cash", UDim2.new(1, -8, 0, 34), frame)
		cashRow.LayoutOrder = 100
		Ui.list(cashRow, Enum.FillDirection.Horizontal, 3)
		local amount = Ui.label("Amount", cashRow, UDim2.fromOffset(58, 30), 17, Theme.font.display)
		amount.Text = `${side.cash}`
		amount.LayoutOrder = 0
		for i, step in CASH_STEPS do
			local button = Ui.button(if step > 0 then `+{step}` else `{step}`, cashRow, function()
				TradeBuilder.stepCash(builder, sideName, step, owner.money)
				changed()
			end, "secondary")
			button.Size = UDim2.fromOffset(38, 30)
			button.LayoutOrder = i
			Ui.setTextSize(button, 12)
		end

		if owner.jailCards > 0 then
			local cardRow = Ui.frame("JailCards", UDim2.new(1, -8, 0, 34), frame)
			cardRow.LayoutOrder = 101
			Ui.list(cardRow, Enum.FillDirection.Horizontal, 3)
			local count = Ui.label("Count", cardRow, UDim2.fromOffset(150, 30), 15)
			count.Text = `Jail cards: {side.jailCards}`
			count.LayoutOrder = 0
			for i, step in { -1, 1 } do
				local button = Ui.button(if step > 0 then "+" else "−", cardRow, function()
					TradeBuilder.stepJailCards(builder, sideName, step, owner.jailCards)
					changed()
				end, "secondary")
				button.Size = UDim2.fromOffset(34, 30)
				button.LayoutOrder = i
			end
		end
	end
	column("give", localId, 0)
	column("get", builder.partner, 0.5)

	-- Footer: why it can't be sent, or Send; Cancel always.
	local footer = Ui.frame("Footer", UDim2.new(1, -24, 0, 48), window)
	footer.Position = UDim2.new(0, 12, 1, -58)
	Ui.list(footer, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	local hint = Ui.label("Hint", footer, UDim2.fromOffset(320, 44), 15, Theme.font.body)
	hint.TextColor3 = Theme.color.moneyDown
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = if ok then "" else reason or ""
	hint.LayoutOrder = 1
	local cancel = Ui.button("Cancel", footer, function()
		self.hooks.close()
	end, "secondary")
	cancel.LayoutOrder = 2
	local send = Ui.button("Send offer", footer, function()
		-- A swallowed click keeps the window and the offer, so nothing is lost.
		if TradeBuilder.check(snapshot, localId, builder) and self.hooks.send({ type = "ProposeTrade", offer = TradeBuilder.offer(builder) }) then
			self.hooks.close()
		end
	end, if ok then "primary" else "disabled")
	send.LayoutOrder = 3
end

-- Forgets what was drawn and hides (back to the lobby).
function TradeWindow.reset(self: TradeWindow)
	self.key = nil
	self.frame.Visible = false
end

return TradeWindow
