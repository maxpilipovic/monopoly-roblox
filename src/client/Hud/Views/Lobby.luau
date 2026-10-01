--!strict
-- The lobby card: how many seats, the match settings, and Start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local Lobby = {}
Lobby.__index = Lobby

Lobby.TITLE = "MONOPOLY"
local MIN_SEATS, MAX_SEATS = 2, TokenLayout.MAX_SEATS

export type Lobby = typeof(setmetatable(
	{} :: { frame: Frame, seats: number, settings: MatchSettings.Settings, seatsLabel: TextLabel, dots: { Frame } },
	Lobby
))

local function refreshSeats(self: Lobby)
	self.seatsLabel.Text = `Players: {self.seats} (bots fill empty seats)`
	for seat, dot in self.dots do
		local filled = seat <= self.seats
		dot.BackgroundColor3 = if filled then TokenLayout.SEAT_COLORS[seat] else Theme.color.surfaceHigh
		dot.BackgroundTransparency = if filled then 0 else 0.4
	end
end

function Lobby.new(parent: Instance, onStart: (seats: number, settings: MatchSettings.Settings) -> ()): Lobby
	local frame = Ui.panel("Lobby", UDim2.fromOffset(380, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.m)
	Ui.padding(frame, Theme.space.l)

	local title = Ui.label("Title", frame, UDim2.new(1, 0, 0, 46), 42, Theme.font.display)
	title.Text = Lobby.TITLE
	title.TextColor3 = Theme.color.accent
	title.LayoutOrder = 1

	-- Seats: a stepper around six token dots, one per possible seat.
	local seatRow = Ui.surface("SeatRow", UDim2.new(1, 0, 0, 64), frame)
	seatRow.LayoutOrder = 2
	Ui.list(seatRow, Enum.FillDirection.Horizontal, Theme.space.m)

	local self = setmetatable({
		frame = frame,
		seats = 4,
		settings = MatchSettings.validate(nil),
		seatsLabel = nil :: any,
		dots = {},
	}, Lobby)

	local function changeSeats(delta: number)
		self.seats = math.clamp(self.seats + delta, MIN_SEATS, MAX_SEATS)
		refreshSeats(self)
	end
	local minus = Ui.button("-", seatRow, function()
		changeSeats(-1)
	end, "secondary")
	minus.Size = UDim2.fromOffset(44, 44)
	minus.LayoutOrder = 1
	local dotRow = Ui.frame("Dots", UDim2.fromOffset(6 * 22 + 5 * 8, 44), seatRow)
	dotRow.LayoutOrder = 2
	Ui.list(dotRow, Enum.FillDirection.Horizontal, 8)
	for seat = 1, MAX_SEATS do
		local dot = Ui.dot(dotRow, TokenLayout.SEAT_COLORS[seat], 22)
		dot.LayoutOrder = seat
		table.insert(self.dots, dot)
	end
	local plus = Ui.button("+", seatRow, function()
		changeSeats(1)
	end, "secondary")
	plus.Size = UDim2.fromOffset(44, 44)
	plus.LayoutOrder = 3

	self.seatsLabel = Ui.label("Seats", frame, UDim2.new(1, 0, 0, 18), Theme.textSize.small, Theme.font.body)
	self.seatsLabel.TextColor3 = Theme.color.textDim
	self.seatsLabel.LayoutOrder = 3

	-- Match settings: each button cycles through its choices.
	local function settingButton(order: number, label: () -> string, cycle: () -> ())
		local button: TextButton
		button = Ui.button(label(), frame, function()
			cycle()
			Ui.setText(button, label())
		end, "secondary")
		button.Size = UDim2.new(1, 0, 0, 42)
		button.LayoutOrder = order
	end
	settingButton(4, function()
		return MatchSettings.timerLabel(self.settings.timer)
	end, function()
		self.settings.timer = MatchSettings.nextTimer(self.settings.timer)
	end)
	settingButton(5, function()
		return MatchSettings.lengthLabel(self.settings.length)
	end, function()
		self.settings.length = MatchSettings.nextLength(self.settings.length)
	end)
	settingButton(6, function()
		return MatchSettings.mapLabel(self.settings.map)
	end, function()
		self.settings.map = MatchSettings.nextMap(self.settings.map)
	end)

	local start = Ui.button("Start game", frame, function()
		onStart(self.seats, table.clone(self.settings))
	end, "primary")
	start.Size = UDim2.new(1, 0, 0, 58)
	start.LayoutOrder = 7
	Ui.setTextSize(start, 24)

	refreshSeats(self)
	return self
end

return Lobby
