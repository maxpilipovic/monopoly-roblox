--!strict
-- Client-side token pieces: one per seat, hopping tile to tile when their player moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local HOP_TIME = 0.18
local HOP_HEIGHT = 1.5
local TOKEN_HEIGHT = 0.8

type Token = {
	part: BasePart,
	seat: number,
	position: number, -- the server's position for this player; tokens settle here once their moves finish
	queue: { { from: number, to: number } },
	moving: boolean,
}

local Tokens = {}
Tokens.__index = Tokens

export type TokensView = typeof(setmetatable({} :: { folder: Folder, tokens: { [string]: Token } }, Tokens))

function Tokens.new(parent: Instance): TokensView
	local folder = Instance.new("Folder")
	folder.Name = "Tokens"
	folder.Parent = parent
	return setmetatable({ folder = folder, tokens = {} }, Tokens)
end

local function standingCFrame(position: number, seat: number): CFrame
	-- Cylinders lie along X; rotate so the token stands upright.
	return CFrame.new(TokenLayout.spot(position, seat) + Vector3.new(0, TOKEN_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

local function makePart(seat: number, name: string, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(TOKEN_HEIGHT, TokenLayout.TOKEN_DIAMETER, TokenLayout.TOKEN_DIAMETER)
	part.Color = TokenLayout.SEAT_COLORS[seat]
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function hop(token: Token, to: number)
	local goal = standingCFrame(to, token.seat)
	local up = TweenService:Create(token.part, TweenInfo.new(HOP_TIME / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = token.part.CFrame:Lerp(goal, 0.5) + Vector3.new(0, HOP_HEIGHT, 0),
	})
	up:Play()
	up.Completed:Wait()
	local down = TweenService:Create(token.part, TweenInfo.new(HOP_TIME / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = goal,
	})
	down:Play()
	down.Completed:Wait()
end

-- Plays queued moves one after another, one hop per tile.
local function runQueue(token: Token)
	if token.moving then
		return
	end
	token.moving = true
	task.spawn(function()
		while #token.queue > 0 do
			local move = table.remove(token.queue, 1) :: { from: number, to: number }
			local steps = (move.to - move.from) % Tiles.COUNT
			for step = 1, steps do
				hop(token, (move.from + step) % Tiles.COUNT)
			end
		end
		token.moving = false
		-- Settle on the server's position, in case a change arrived without a move to animate.
		if token.part.Parent then
			token.part.CFrame = standingCFrame(token.position, token.seat)
		end
	end)
end

-- Where a newly created token should appear: at the start of its first move in this update, so the
-- move animates from there, otherwise at the player's current position.
function Tokens.startPosition(player: Protocol.PlayerView, events: { { [string]: any } }): number
	for _, event in events do
		if event.type == "Moved" and event.player == player.id then
			return event.from
		end
	end
	return player.position
end

function Tokens.apply(self: TokensView, update: Protocol.Update)
	local snapshot = update.snapshot
	local seen = {}

	if snapshot then
		for _, player in snapshot.players do
			seen[player.id] = true
			local token = self.tokens[player.id]
			if not token then
				local part = makePart(player.seat, player.name, self.folder)
				part.CFrame = standingCFrame(Tokens.startPosition(player, update.events), player.seat)
				token = { part = part, seat = player.seat, position = player.position, queue = {}, moving = false }
				self.tokens[player.id] = token
			end
			token.position = player.position
			token.part.Transparency = if player.bankrupt then 0.7 else 0
		end
	end

	for id, token in self.tokens do
		if not seen[id] then
			token.part:Destroy()
			self.tokens[id] = nil
		end
	end

	for _, event in update.events do
		local token = event.type == "Moved" and self.tokens[event.player]
		if token then
			table.insert(token.queue, { from = event.from, to = event.to })
			runQueue(token)
		end
	end

	-- Tokens with nothing to animate snap to where the server says they are.
	for _, token in self.tokens do
		if not token.moving then
			token.part.CFrame = standingCFrame(token.position, token.seat)
		end
	end
end

return Tokens
