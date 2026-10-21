--!strict
-- Client-side token pieces: one per seat, hopping tile to tile when their player moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local PieceLook = require(ReplicatedStorage.Shared.Cosmetics.PieceLook)
local PieceEffects = require(script.Parent.PieceEffects)

local HOP_HEIGHT = 1.5
local JAIL_HOP_HEIGHT = 6 -- the jump to jail is a high flip
local LEAN = math.rad(16) -- tilt into each hop
local RIPPLE_SECONDS = 0.6
local TOKEN_HEIGHT = 0.8

-- pause: seconds the token waits before setting off (the dice, or a card being read).
-- flight: a card sends it there; it flies over the board in one arc instead of walking.
type Move = { from: number, to: number, style: string?, pause: number?, flight: boolean? }

type Token = {
	part: BasePart,
	piece: Model?, -- the piece's model, welded to `part` (nil: the plain cylinder shows)
	seat: number,
	position: number, -- the server's position for this player; tokens settle here once their moves finish
	inJail: boolean,
	queue: { Move },
	moving: boolean,
	index: number, -- its place among the pieces sharing its tile (TokenLayout arranges them)
	count: number, -- how many share it
}

local Tokens = {}
Tokens.__index = Tokens

local settle: (any) -> ()

Tokens.HOP_TIME = Pacing.HOP_SECONDS
local HOP_TIME = Tokens.HOP_TIME

-- Optional listeners for the camera: a move begins, each hop, and the token's queue runs dry.
export type TokenHooks = {
	onMoveStarted: (part: BasePart, style: string?) -> (),
	onHop: (part: BasePart, from: number, to: number) -> (),
	onMoveFinished: (part: BasePart) -> (),
}

export type TokensView = typeof(setmetatable(
	{} :: { folder: Folder, tokens: { [string]: Token }, hooks: TokenHooks? },
	Tokens
))

function Tokens.new(parent: Instance, hooks: TokenHooks?): TokensView
	local folder = Instance.new("Folder")
	folder.Name = "Tokens"
	folder.Parent = parent
	return setmetatable({ folder = folder, tokens = {}, hooks = hooks }, Tokens)
end

local function standingCFrame(position: number, index: number, count: number, jailed: boolean?): CFrame
	local spot = if jailed then TokenLayout.jailSpot(index, count) else TokenLayout.spot(position, index, count)
	-- Cylinders lie along X; rotate so the token stands upright.
	return CFrame.new(spot + Vector3.new(0, TOKEN_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
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

local PIECE_HEIGHT = 2.8 -- studs; pieces are scaled to this (narrow enough for their spot)
local PIECE_WIDTH = 1.75

-- The player's piece standing on the token's spot, with a ring in their seat colour round its foot.
-- Welded to the (now invisible) token part, so moving that part moves the piece.
local function attachPiece(part: BasePart, seat: number, piece: string?, aura: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local id = if piece and Catalog.byId[piece] then piece else Catalog.DEFAULT_PIECE
	local kind, shape = Catalog.modelOf(id)
	local folder = assets and assets:FindFirstChild(kind)
	local source = folder and folder:FindFirstChild(shape)
	if not (source and source:IsA("Model")) then
		return nil
	end
	local model = source:Clone()
	PieceLook.apply(model, id)
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	model:ScaleTo(math.min(PIECE_HEIGHT / size.Y, PIECE_WIDTH / math.max(size.X, size.Z)))
	local ring = Instance.new("Part")
	ring.Name = "SeatRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, TokenLayout.TOKEN_DIAMETER, TokenLayout.TOKEN_DIAMETER)
	ring.Color = TokenLayout.SEAT_COLORS[seat]
	ring.Material = Enum.Material.SmoothPlastic
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CFrame = model:GetPivot() * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = model
	-- The piece's base sits where the cylinder's base was; it faces the players (+Z).
	model:PivotTo(CFrame.new(part.Position - Vector3.new(0, TOKEN_HEIGHT / 2, 0)))
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = child
			weld.Parent = child
		end
	end
	model.Name = "Piece"
	model.Parent = part
	local item = Catalog.byId[id]
	PieceEffects.attach(model, item and item.effect)
	-- An aura is worn on top of whatever the piece does itself.
	local worn = if aura then Catalog.byId[aura] else nil
	if worn and worn.kind == "Aura" then
		PieceEffects.attach(model, worn.effect)
	end
	part.Transparency = 1
	return model
end

-- One hop along an arc: the token leans into it, and a jump to jail flips end over end. Driven
-- frame by frame rather than tweened, so the arc and the flip stay in step.
local function hop(token: Token, goal: CFrame, toJail: boolean)
	local part = token.part
	local start = part.CFrame
	local travel = (goal.Position - start.Position) * Vector3.new(1, 0, 1)
	local axis = if travel.Magnitude > 0.01 then Vector3.yAxis:Cross(travel.Unit) else Vector3.xAxis
	local height = if toJail then JAIL_HOP_HEIGHT else HOP_HEIGHT
	local began = os.clock()
	while part.Parent do
		local t = math.min((os.clock() - began) / HOP_TIME, 1)
		local position = start.Position:Lerp(goal.Position, t) + Vector3.new(0, 4 * height * t * (1 - t), 0)
		local turn = if toJail then t * 2 * math.pi else math.sin(t * math.pi) * LEAN
		part.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(axis, turn) * goal.Rotation
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

-- A card sending the token somewhere: it lifts off, flies across the board in one high arc while
-- turning once, and comes down on its spot, all in Pacing.FLIGHT_SECONDS.
local function fly(token: Token, goal: CFrame)
	local part = token.part
	local start = part.CFrame
	local distance = (goal.Position - start.Position).Magnitude
	local height = 7 + distance * 0.18
	local began = os.clock()
	while part.Parent do
		local t = math.min((os.clock() - began) / Pacing.FLIGHT_SECONDS, 1)
		local eased = t * t * (3 - 2 * t) -- slow off the ground, fast across, slow onto the tile
		local position = start.Position:Lerp(goal.Position, eased) + Vector3.new(0, 4 * height * t * (1 - t), 0)
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, eased * 2 * math.pi, 0) * goal.Rotation
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

-- The end of a move: the token squashes as it settles and a ring in its colour ripples out.
local function land(token: Token)
	local part = token.part
	if not part.Parent then
		return
	end
	local size = Vector3.new(TOKEN_HEIGHT, TokenLayout.TOKEN_DIAMETER, TokenLayout.TOKEN_DIAMETER) -- its rest size, not a mid-squash one
	part.Size = Vector3.new(size.X * 0.75, size.Y * 1.18, size.Z * 1.18)
	TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()

	local ring = Instance.new("Part")
	ring.Name = "Ripple"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.05, TokenLayout.TOKEN_DIAMETER, TokenLayout.TOKEN_DIAMETER)
	ring.CFrame = CFrame.new(part.Position - Vector3.new(0, TOKEN_HEIGHT / 2 - 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = TokenLayout.SEAT_COLORS[token.seat]
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = part.Parent
	local grown = TokenLayout.TOKEN_DIAMETER * 3.2
	TweenService:Create(ring, TweenInfo.new(RIPPLE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, grown, grown),
		Transparency = 1,
	}):Play()
	task.delay(RIPPLE_SECONDS + 0.05, function()
		ring:Destroy()
	end)
end

-- The piece standing for `player`, if there is one (for effects that play over it).
function Tokens.partFor(self: TokensView, player: string): BasePart?
	local token = self.tokens[player]
	return if token then token.part else nil
end

-- The tiles a token hops through to play out a Moved event.
function Tokens.path(move: Move): { number }
	if move.style == "ToJail" then
		return { move.to }
	end
	local direction = if move.style == "Back" then -1 else 1
	local steps = (direction * (move.to - move.from)) % Tiles.COUNT
	local path = {}
	for step = 1, steps do
		table.insert(path, (move.from + direction * step) % Tiles.COUNT)
	end
	return path
end

-- How long a Moved event takes to animate.
function Tokens.moveSeconds(move: Move): number
	if move.flight then
		return Pacing.FLIGHT_SECONDS
	end
	return #Tokens.path(move) * HOP_TIME
end

-- Slides every token that isn't mid-move to its place, as tiles fill and empty.
function settle(self: TokensView)
	for _, token in self.tokens do
		if not token.moving and token.part.Parent then
			local goal = standingCFrame(token.position, token.index, token.count, token.inJail)
			if (token.part.Position - goal.Position).Magnitude > 0.05 then
				TweenService:Create(token.part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
			end
		end
	end
end

-- Plays queued moves one after another, one hop per tile.
local function runQueue(self: TokensView, token: Token)
	if token.moving then
		return
	end
	token.moving = true
	task.spawn(function()
		local hooks = self.hooks
		while #token.queue > 0 and token.part.Parent do
			local move = table.remove(token.queue, 1) :: Move
			if move.pause and move.pause > 0 then
				task.wait(move.pause)
				if not token.part.Parent then
					break
				end
			end
			if move.flight then
				if hooks then
					hooks.onMoveStarted(token.part, "Fly")
				end
				local last = #token.queue == 0
				fly(token, standingCFrame(move.to, if last then token.index else 1, if last then token.count else 1, false))
				settle(self)
				land(token)
				settle(self)
				continue
			end
			if hooks then
				hooks.onMoveStarted(token.part, move.style)
			end
			local previous = move.from
			local path = Tokens.path(move)
			for step, position in path do
				if not token.part.Parent then
					break -- the token was removed (back to the lobby) mid-move
				end
				if hooks then
					hooks.onHop(token.part, previous, position)
				end
				-- Tiles passed through are hopped across in the middle; the last one, in its own place.
				local last = step == #path and #token.queue == 0
				local jailed = move.style == "ToJail"
				hop(token, standingCFrame(position, if last then token.index else 1, if last then token.count else 1, jailed), jailed)
				if step == 1 then
					settle(self) -- whoever it left behind spreads back out
				end
				previous = position
			end
			land(token)
			settle(self) -- and whoever it joined makes room
		end
		token.moving = false
		if hooks then
			hooks.onMoveFinished(token.part)
		end
		-- Settle on the server's position, in case a change arrived without a move to animate.
		settle(self)
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
				part.CFrame = standingCFrame(Tokens.startPosition(player, update.events), 1, 1)
				local piece = attachPiece(part, player.seat, player.piece, player.aura)
				token = {
					part = part,
					piece = piece,
					seat = player.seat,
					position = player.position,
					inJail = player.inJail,
					queue = {},
					moving = false,
					index = 1,
					count = 1,
				}
				self.tokens[player.id] = token
			end
			token.position = player.position
			token.inJail = player.inJail
			if not token.piece then
				-- The model may have finished loading since the token was made.
				token.piece = attachPiece(token.part, token.seat, player.piece, player.aura)
			end
			if token.piece then
				for _, child in (token.piece :: Model):GetDescendants() do
					if child:IsA("BasePart") then
						child.LocalTransparencyModifier = if player.bankrupt then 0.7 else 0
					elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Light") then
						child.Enabled = not player.bankrupt -- a bankrupt piece stops showing off
					end
				end
			else
				token.part.Transparency = if player.bankrupt then 0.7 else 0
			end
		end
	end

	for id, token in self.tokens do
		if not seen[id] then
			token.part:Destroy()
			self.tokens[id] = nil
		end
	end

	-- Who shares each tile (the jail cell counts as its own), in seat order, decides where each stands.
	local groups: { [string]: { Token } } = {}
	for _, token in self.tokens do
		local key = if token.inJail then "jail" else tostring(token.position)
		groups[key] = groups[key] or {}
		table.insert(groups[key], token)
	end
	for _, group in groups do
		table.sort(group, function(a, b)
			return a.seat < b.seat
		end)
		for index, token in group do
			token.index = index
			token.count = #group
		end
	end

	for _, event in update.events do
		local token = event.type == "Moved" and self.tokens[event.player]
		if token then
			table.insert(token.queue, { from = event.from, to = event.to, style = event.style, pause = event.pause, flight = event.flight })
			runQueue(self, token)
		end
	end

	-- Tokens with nothing to animate go to where the server says they are.
	settle(self)
end

return Tokens
