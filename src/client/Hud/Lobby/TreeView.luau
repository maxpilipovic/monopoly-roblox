--!strict
-- The Empire Tree drawn as a map you drag around and zoom: the root in the middle, six coloured
-- branches growing out, a line between each node and the one it opens from. A node shows its state:
-- locked (dim, padlock), open (its stat's icon and a progress bar), ready (gold and pulsing) or
-- claimed (filled in its branch's colour with a tick). Branch tips are bigger and starred.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Stats = require(ReplicatedStorage.Shared.Progress.Stats)
local Tree = require(ReplicatedStorage.Shared.Progress.Tree)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TreeView = {}

export type ViewState = { zoom: number, canvas: Vector2?, selected: string? }

TreeView.MARGIN = 110
TreeView.MIN_ZOOM = 0.35
TreeView.MAX_ZOOM = 1.1
local NODE = 58
local TIP = 74
local ROOT = 88
local LINE = 7
local GOLD = Color3.fromRGB(255, 204, 72)
local LOCKED = Color3.fromRGB(34, 40, 60)
local DRAG_SLOP = 6

local HALF = Tree.EXTENT + TreeView.MARGIN
TreeView.SIZE = HALF * 2

-- How much the HUD around `gui` is scaled (the lobby shrinks to fit short screens): screen pixels
-- per canvas pixel.
local function hudScale(gui: Instance): number
	local fit = 1
	local ancestor = gui.Parent
	while ancestor do
		local uiScale = ancestor:FindFirstChildOfClass("UIScale")
		if uiScale then
			fit *= uiScale.Scale
		end
		ancestor = ancestor.Parent
	end
	return math.max(fit, 0.01)
end

-- The map's visible window, in canvas pixels.
function TreeView.window(scroll: ScrollingFrame): Vector2
	return scroll.AbsoluteWindowSize / hudScale(scroll)
end

local function at(position: Vector2): Vector2
	return Vector2.new(HALF + position.X, HALF + position.Y)
end

local function line(parent: Instance, from: Vector2, to: Vector2, color: Color3, transparency: number)
	local delta = to - from
	local bar = Instance.new("Frame")
	bar.Name = "Line"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
	bar.Size = UDim2.fromOffset(delta.Magnitude, LINE)
	bar.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = transparency
	bar.BorderSizePixel = 0
	bar.ZIndex = 2
	bar.Parent = parent
	Ui.corner(bar, LINE)
end

local function pulse(object: GuiObject)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.85, Size = object.Size + UDim2.fromOffset(16, 16) }
	)
	tween:Play()
end

-- Draws the tree into `parent` (sized to fill it). `onSelect` hears a node clicked (not dragged).
function TreeView.build(parent: GuiObject, data: Progress.Data, state: ViewState, onSelect: (string) -> ()): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TreeMap"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundColor3 = Color3.fromRGB(14, 18, 32)
	scroll.BackgroundTransparency = 0
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.CanvasSize = UDim2.fromOffset(TreeView.SIZE * state.zoom, TreeView.SIZE * state.zoom)
	scroll.Parent = parent
	Ui.corner(scroll, Theme.radius.surface)

	local map = Ui.frame("Map", UDim2.fromOffset(TreeView.SIZE, TreeView.SIZE), scroll)
	local scale = Instance.new("UIScale")
	scale.Scale = state.zoom
	scale.Parent = map

	-- Faint rings, like a target, so the map reads as one picture.
	for ring = 1, 4 do
		local radius = Tree.RADIUS_START + (ring * 2 - 1) * Tree.STEP
		local circle = Instance.new("Frame")
		circle.Name = "Ring"
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromOffset(HALF, HALF)
		circle.Size = UDim2.fromOffset(radius * 2, radius * 2)
		circle.BackgroundTransparency = 1
		circle.ZIndex = 1
		circle.Parent = map
		Ui.corner(circle, radius)
		Ui.stroke(circle, Color3.fromRGB(80, 96, 140), 2, 0.8)
	end

	-- Lines first, under the nodes.
	for _, node in Tree.NODES do
		if node.parent then
			local parentNode = Tree.byId[node.parent]
			local branch = Tree.branchById[node.branch :: string]
			local claimed = data.tree.claimed[node.id] == true
			local open = (Progress.node(data, node.id)) ~= "Locked"
			-- Locked stretches stay faintly in their branch's colour, so the whole tree reads at a glance.
			line(map, at(parentNode.position), at(node.position), branch.color, if claimed then 0 elseif open then 0.35 else 0.78)
		end
	end

	-- Branch names, past each branch's tip.
	for _, branch in Tree.BRANCHES do
		local r = math.rad(branch.angle)
		local direction = Vector2.new(math.cos(r), math.sin(r))
		local spot = at(direction * (Tree.EXTENT + 62))
		local label = Ui.label(branch.id, map, UDim2.fromOffset(220, 40), 30, Theme.font.display)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(spot.X, spot.Y)
		label.TextColor3 = branch.color
		label.TextStrokeTransparency = 0.5
		label.Text = string.upper(branch.name)
		label.ZIndex = 3
	end

	local drag = { down = false, moved = 0, start = Vector2.zero, canvas = Vector2.zero }

	for _, node in Tree.NODES do
		local nodeState, progress, target = Progress.node(data, node.id)
		local branch = if node.branch then Tree.branchById[node.branch] else nil
		local color = if branch then branch.color else GOLD
		local size = if node.id == Tree.ROOT then ROOT elseif node.tip then TIP else NODE
		local spot = at(node.position)

		if nodeState == "Ready" then
			local glow = Instance.new("Frame")
			glow.Name = "Glow"
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromOffset(spot.X, spot.Y)
			glow.Size = UDim2.fromOffset(size + 14, size + 14)
			glow.BackgroundColor3 = GOLD
			glow.BackgroundTransparency = 0.45
			glow.ZIndex = 3
			glow.Parent = map
			Ui.corner(glow, size)
			pulse(glow)
		end

		local button = Instance.new("TextButton")
		button.Name = node.id
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromOffset(spot.X, spot.Y)
		button.Size = UDim2.fromOffset(size, size)
		button.AutoButtonColor = nodeState ~= "Locked"
		button.Text = ""
		button.ZIndex = 4
		button.BackgroundColor3 = if nodeState == "Claimed" then color
			elseif nodeState == "Ready" then GOLD
			elseif nodeState == "Active" then Theme.color.surfaceHigh
			else LOCKED
		button.Parent = map
		Ui.corner(button, size)
		local ring = Ui.stroke(button, color, if state.selected == node.id then 5 else 3, if nodeState == "Locked" then 0.55 else 0)
		if state.selected == node.id then
			ring.Color = Color3.new(1, 1, 1)
		end

		local icon = Ui.label("Icon", button, UDim2.fromScale(1, 1), size * 0.5, Theme.font.display)
		icon.ZIndex = 5
		icon.Text = if node.id == Tree.ROOT then "🏁"
			elseif nodeState == "Claimed" then "✓"
			elseif nodeState == "Locked" then "🔒"
			else Stats.byId[node.stat].icon
		icon.TextColor3 = if nodeState == "Claimed" then Theme.color.ink else Theme.color.text
		icon.TextTransparency = if nodeState == "Locked" then 0.55 else 0
		if node.tip then
			local star = Ui.label("Star", button, UDim2.fromOffset(28, 28), 22, Theme.font.display)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Position = UDim2.new(1, -6, 0, 6)
			star.ZIndex = 6
			star.Text = "⭐"
		end
		if nodeState == "Active" then
			local track = Instance.new("Frame")
			track.Name = "Progress"
			track.AnchorPoint = Vector2.new(0.5, 0)
			track.Position = UDim2.new(0.5, 0, 1, 6)
			track.Size = UDim2.fromOffset(size, 7)
			track.BackgroundColor3 = LOCKED
			track.BorderSizePixel = 0
			track.ZIndex = 5
			track.Parent = button
			Ui.corner(track, 4)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
			fill.BackgroundColor3 = color
			fill.BorderSizePixel = 0
			fill.ZIndex = 6
			fill.Parent = track
			Ui.corner(fill, 4)
		elseif nodeState == "Ready" then
			local bang = Ui.label("Ready", button, UDim2.fromOffset(26, 26), 18, Theme.font.display)
			bang.AnchorPoint = Vector2.new(0.5, 0.5)
			bang.Position = UDim2.new(0, 6, 0, 6)
			bang.BackgroundTransparency = 0
			bang.BackgroundColor3 = Theme.color.danger
			bang.ZIndex = 6
			bang.Text = "!"
			Ui.corner(bang, 13)
		end
		button.Activated:Connect(function()
			if drag.moved <= DRAG_SLOP then
				onSelect(node.id)
			end
		end)
	end

	-- Where to look: as the player left it, else the root in the middle.
	task.defer(function()
		local view = TreeView.window(scroll)
		local centre = Vector2.new(HALF, HALF) * state.zoom
		scroll.CanvasPosition = state.canvas or (centre - view / 2)
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		state.canvas = scroll.CanvasPosition
	end)

	-- Drag with the mouse to pan (touch already pans a ScrollingFrame).
	local connections = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not scroll.Visible then
			return
		end
		local mouse = Vector2.new(input.Position.X, input.Position.Y)
		local min, max = scroll.AbsolutePosition, scroll.AbsolutePosition + scroll.AbsoluteSize
		if mouse.X >= min.X and mouse.Y >= min.Y and mouse.X <= max.X and mouse.Y <= max.Y then
			drag.down = true
			drag.moved = 0
			drag.start = mouse
			drag.canvas = scroll.CanvasPosition
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if drag.down and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mouse = Vector2.new(input.Position.X, input.Position.Y)
			local delta = mouse - drag.start
			drag.moved = math.max(drag.moved, delta.Magnitude)
			-- Screen pixels to canvas pixels: the lobby HUD itself may be scaled down to fit.
			scroll.CanvasPosition = drag.canvas - delta / hudScale(scroll)
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			drag.down = false
			-- Let this release's click see how far it dragged, then forget it.
			task.defer(function()
				drag.moved = 0
			end)
		end
	end))
	scroll.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	return scroll
end

-- Zooms by `factor`, keeping the middle of the view where it was.
function TreeView.zoom(state: ViewState, factor: number, windowSize: Vector2)
	local old = state.zoom
	local new = math.clamp(old * factor, TreeView.MIN_ZOOM, TreeView.MAX_ZOOM)
	local canvas = state.canvas or (Vector2.new(HALF, HALF) * old - windowSize / 2)
	local middle = (canvas + windowSize / 2) / old
	state.zoom = new
	state.canvas = middle * new - windowSize / 2
end

-- Points the view at a node.
function TreeView.focus(state: ViewState, nodeId: string, windowSize: Vector2)
	local node = Tree.byId[nodeId]
	if node then
		state.canvas = at(node.position) * state.zoom - windowSize / 2
	end
end

return TreeView
