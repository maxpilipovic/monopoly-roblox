--!strict
-- "+$40" and "−$40" floating up from the tokens when money changes hands, so a payment is seen on the
-- board and not only in the player list. Passing Go also lights the Go tile.

local TweenService = game:GetService("TweenService")

export type Pop = { player: string, amount: number } -- negative: the player paid

local MoneyPops = {}

local GAIN = Color3.fromRGB(126, 226, 168)
local LOSS = Color3.fromRGB(255, 139, 139)
local RISE_STUDS = 4
local SECONDS = 1.4

-- Who to pop over for an event: both players for a payment between them, just the player when the
-- bank is the other side.
function MoneyPops.fromEvent(event: { [string]: any }): { Pop }
	local pops: { Pop } = {}
	if event.type ~= "Paid" or (event.amount or 0) <= 0 then
		return pops
	end
	if event.from then
		table.insert(pops, { player = event.from, amount = -event.amount })
	end
	if event.to then
		table.insert(pops, { player = event.to, amount = event.amount })
	end
	return pops
end

function MoneyPops.passedGo(event: { [string]: any }): boolean
	return event.type == "Paid" and event.reason == "Go"
end

-- Floats `pop` up from above `part` and fades it out.
function MoneyPops.show(part: BasePart, pop: Pop)
	local holder = Instance.new("Part")
	holder.Name = "MoneyPop"
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
	holder.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextSize = 34
	label.TextColor3 = if pop.amount >= 0 then GAIN else LOSS
	label.Text = if pop.amount >= 0 then `+${pop.amount}` else `−${-pop.amount}`
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.3
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label

	local info = TweenInfo.new(SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, info, { CFrame = holder.CFrame + Vector3.new(0, RISE_STUDS, 0) }):Play()
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(SECONDS * 0.55, function()
		local fade = TweenInfo.new(SECONDS * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end)
	task.delay(SECONDS + 0.1, function()
		holder:Destroy()
	end)
end

-- A gold flash over the Go tile: a thin glowing slab that swells and fades.
function MoneyPops.flashTile(tile: BasePart)
	local glow = Instance.new("Part")
	glow.Name = "GoFlash"
	glow.Size = Vector3.new(tile.Size.X, 0.05, tile.Size.Z)
	glow.CFrame = tile.CFrame * CFrame.new(0, tile.Size.Y / 2 + 0.06, 0)
	glow.Color = Color3.fromRGB(255, 214, 102)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.25
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	glow.Parent = workspace
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(glow, info, { Transparency = 1, Size = glow.Size + Vector3.new(1.5, 0, 1.5) }):Play()
	task.delay(1, function()
		glow:Destroy()
	end)
end

return MoneyPops
