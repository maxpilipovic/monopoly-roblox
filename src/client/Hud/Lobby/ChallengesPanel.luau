--!strict
-- The Challenges panel: three tabs.
--   Daily         today's three challenges as cards (easy, medium, hard), a swap a day, a bonus for all three
--   Achievements  every lifetime track with its five medals, next goal and reward
--   Empire Tree   the big map (TreeView) and the selected node's card: goal, progress, reward, claim
-- Everything is read from the player's own profile with Shared.Progress.Progress, so what it shows
-- is exactly what the server will allow; claims go to the server, which checks again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(ReplicatedStorage.Shared.Progress.Achievements)
local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Dailies = require(ReplicatedStorage.Shared.Progress.Dailies)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
local Stats = require(ReplicatedStorage.Shared.Progress.Stats)
local Tree = require(ReplicatedStorage.Shared.Progress.Tree)
local Icons = require(script.Parent.Parent.Icons)
local ItemArt = require(script.Parent.ItemArt)
local TreeView = require(script.Parent.TreeView)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)
local Sounds = require(script.Parent.Parent.Parent.Sounds)

local ChallengesPanel = {}

ChallengesPanel.SIZE = Vector2.new(940, 600)
ChallengesPanel.TABS = { "Daily", "Achievements", "Empire Tree" }

local GOLD = Color3.fromRGB(255, 204, 72)
local TRACK = Color3.fromRGB(22, 28, 46)

-- A rounded progress bar with "n / target" on it.
local function bar(parent: Instance, size: UDim2, fraction: number, color: Color3, text: string?): Frame
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.Size = size
	track.BackgroundColor3 = TRACK
	track.BorderSizePixel = 0
	track.Parent = parent
	Ui.corner(track, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Visible = fraction > 0
	fill.Parent = track
	Ui.corner(fill, 8)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 90
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200))
	shine.Parent = fill
	if text then
		local label = Ui.label("Text", track, UDim2.fromScale(1, 1), 14, Theme.font.display)
		label.TextStrokeTransparency = 0.5
		label.ZIndex = 3
		label.Text = text
	end
	return track
end

local function rewardText(reward: Rewards.Reward): string
	return Rewards.describe(reward, function(id)
		local item = Catalog.byId[id]
		return if item then `{item.name} ({Catalog.KIND_NAMES[item.kind]})` else id
	end)
end

-- The reward as a row of chips: coins, a key, an item in its rarity's colour.
local function rewardChips(parent: Instance, reward: Rewards.Reward, size: number?): Frame
	local row = Ui.frame("Reward", UDim2.new(1, 0, 0, 26), parent)
	Ui.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local function chip(text: string, color: Color3, textColor: Color3?, order: number, icon: string?)
		local pill = Ui.pill(text, row, color, textColor)
		pill.TextSize = size or 14
		pill.Size = UDim2.fromOffset(0, 24)
		pill.LayoutOrder = order
		if icon then
			-- The icon sits in the pill's left padding.
			local padding = pill:FindFirstChildOfClass("UIPadding")
			if padding then
				padding.PaddingLeft = UDim.new(0, 24)
			end
			local image = Icons.image(pill, icon, UDim2.fromOffset(22, 22))
			image.AnchorPoint = Vector2.new(1, 0.5)
			image.Position = UDim2.new(0, -1, 0.5, 0)
		end
	end
	if reward.coins then
		chip(Stats.commas(reward.coins), Color3.fromRGB(70, 56, 20), GOLD, 1, "Coin")
	end
	if reward.key then
		chip(`{reward.key} key`, Color3.fromRGB(40, 50, 80), Theme.color.text, 2, "Key")
	end
	if reward.item then
		local item = Catalog.byId[reward.item]
		if item then
			chip(item.name, Catalog.RARITY_COLORS[item.rarity], Theme.color.ink, 3)
		end
	end
	return row
end

local function badge(parent: Instance, count: number)
	if count <= 0 then
		return
	end
	local dot = Ui.label("Badge", parent, UDim2.fromOffset(24, 24), 14, Theme.font.display)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.BackgroundTransparency = 0
	dot.BackgroundColor3 = Theme.color.danger
	dot.ZIndex = 8
	dot.Text = tostring(count)
	Ui.corner(dot, 12)
	Ui.stroke(dot, Color3.new(1, 1, 1), 1.5, 0.3)
end

ChallengesPanel.badge = badge
ChallengesPanel.bar = bar
ChallengesPanel.rewardChips = rewardChips

local function clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%dh %02dm %02ds", seconds // 3600, seconds // 60 % 60, seconds % 60)
end
ChallengesPanel.clockText = clockText

-- Daily ---------------------------------------------------------------------------------------------

local function renderDaily(hud: any, content: Frame, data: Progress.Data)
	local lines = Progress.dailies(data)
	local top = Ui.frame("Top", UDim2.new(1, 0, 0, 26), content)
	local clock = Ui.label("Clock", top, UDim2.new(0.6, 0, 1, 0), 16, Theme.font.bodyBold)
	clock.TextXAlignment = Enum.TextXAlignment.Left
	clock.TextColor3 = Theme.color.textDim
	Icons.labelled(top, "Clock", 24, clock)
	hud.dailyClock = clock
	local swaps = Ui.label("Swaps", top, UDim2.new(0.4, 0, 1, 0), 15, Theme.font.bodyBold)
	swaps.Position = UDim2.fromScale(0.6, 0)
	swaps.TextXAlignment = Enum.TextXAlignment.Right
	swaps.TextColor3 = Theme.color.textDim
	local swapsLeft = math.max(Dailies.SWAPS_PER_DAY - (data.daily.swaps or 0), 0)
	swaps.Text = `Swaps left today: {swapsLeft}`
	Icons.labelled(top, "Swap", 22, swaps)

	if #lines == 0 then
		local wait = Ui.label("Waiting", content, UDim2.new(1, 0, 0, 200), 20, Theme.font.body)
		wait.Position = UDim2.fromOffset(0, 120)
		wait.TextColor3 = Theme.color.textDim
		wait.Text = "Dealing today's challenges…"
		return
	end

	local row = Ui.frame("Cards", UDim2.new(1, 0, 0, 330), content)
	row.Position = UDim2.fromOffset(0, 36)
	Ui.list(row, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	for _, line in lines do
		local daily = line.daily
		local tierColor = Dailies.TIER_COLORS[daily.tier]
		local card = Ui.surface(`Daily{line.slot}`, UDim2.fromOffset(276, 330), row)
		card.LayoutOrder = line.slot
		if line.ready then
			Ui.stroke(card, GOLD, 3, 0)
		elseif line.claimed then
			card.BackgroundTransparency = 0.4
		end
		local band = Instance.new("Frame")
		band.Name = "Band"
		band.Size = UDim2.new(1, 0, 0, 40)
		band.BackgroundColor3 = tierColor
		band.BorderSizePixel = 0
		band.Parent = card
		Ui.corner(band, Theme.radius.surface)
		local tier = Ui.label("Tier", band, UDim2.fromScale(1, 1), 20, Theme.font.display)
		tier.TextColor3 = Theme.color.ink
		tier.Text = string.upper(daily.tier)
		local icon = Icons.image(card, if line.claimed then "Check" else Stats.byId[daily.stat].icon, UDim2.fromOffset(96, 96))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 38)
		local goal = Ui.label("Goal", card, UDim2.new(1, -24, 0, 56), 21, Theme.font.display)
		goal.Position = UDim2.fromOffset(12, 126)
		goal.Text = Stats.goal(daily.stat, daily.target)
		local progressBar = bar(card, UDim2.new(1, -36, 0, 22), line.progress / daily.target, tierColor,
			`{Stats.amount(daily.stat, line.progress)} / {Stats.amount(daily.stat, daily.target)}`)
		progressBar.Position = UDim2.fromOffset(18, 190)
		local reward = rewardChips(card, { coins = daily.coins }, 16)
		reward.Position = UDim2.fromOffset(0, 222)
		local claim = Ui.button(if line.claimed then "Claimed" elseif line.ready then "Claim!" else "In progress", card, function()
			if line.ready then
				hud.callbacks.onProgress({ type = "ClaimDaily", slot = line.slot })
			end
		end, if line.ready then "accent" else "disabled")
		claim.Size = UDim2.new(1, -36, 0, 46)
		claim.Position = UDim2.new(0, 18, 1, -78)
		if not line.claimed and not line.ready and swapsLeft > 0 then
			local swap = Instance.new("TextButton")
			swap.Name = "Swap"
			swap.Size = UDim2.new(1, 0, 0, 20)
			swap.Position = UDim2.new(0, 0, 1, -26)
			swap.BackgroundTransparency = 1
			swap.FontFace = Theme.font.bodyBold
			swap.TextSize = 14
			swap.TextColor3 = GOLD
			swap.Text = "Swap for another"
			swap.Parent = card
			swap.Activated:Connect(function()
				Sounds.play("Click")
				hud.callbacks.onProgress({ type = "SwapDaily", slot = line.slot })
			end)
		end
	end

	-- The all-three bonus.
	local done = 0
	for _, line in lines do
		if line.claimed then
			done += 1
		end
	end
	local bonus = Ui.surface("Bonus", UDim2.new(1, 0, 0, 70), content)
	bonus.Position = UDim2.new(0, 0, 0, 382)
	local caption = Ui.label("Caption", bonus, UDim2.new(0.55, -20, 1, 0), 18, Theme.font.display)
	caption.Position = UDim2.fromOffset(20, 0)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Text = if data.daily.bonus
		then "Daily bonus collected! Come back tomorrow."
		else `Finish all three for a bonus of {Rewards.DAILY_SWEEP} coins`
	caption.TextColor3 = if data.daily.bonus then Theme.color.moneyUp else Theme.color.text
	local pips = Ui.frame("Pips", UDim2.new(0.45, -20, 1, 0), bonus)
	pips.Position = UDim2.fromScale(0.55, 0)
	Ui.list(pips, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	for index = 1, #lines do
		local pip = Ui.label(`Pip{index}`, pips, UDim2.fromOffset(44, 44), 22, Theme.font.display)
		pip.LayoutOrder = index
		pip.BackgroundTransparency = 0
		pip.BackgroundColor3 = TRACK
		Ui.corner(pip, 22)
		local image = Icons.image(pip, if index <= done then "Check" else "Coin", UDim2.fromScale(0.85, 0.85))
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.ImageTransparency = if index <= done then 0 else 0.7
	end
end

-- Achievements -------------------------------------------------------------------------------------

local function renderAchievements(hud: any, content: Frame, data: Progress.Data)
	local medals, total = 0, 0
	for _, track in Achievements.LIST do
		medals += math.min(data.achievements[track.id] or 0, #track.tiers)
		total += #track.tiers
	end
	local summary = Ui.label("Summary", content, UDim2.new(1, 0, 0, 24), 16, Theme.font.bodyBold)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextColor3 = Theme.color.textDim
	summary.Text = `{medals} of {total} medals · lifetime totals count, from your very first game`
	Icons.labelled(content, "Medal", 24, summary)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Tracks"
	list.Size = UDim2.new(1, 0, 1, -34)
	list.Position = UDim2.fromOffset(0, 32)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 112)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	Ui.padding(list, { right = 10 })

	-- Ready ones first, then the rest in the catalogue's order.
	local order = {}
	for index, track in Achievements.LIST do
		local line = Progress.achievement(data, track.id)
		table.insert(order, { line = line, rank = (if line.ready then 0 elseif line.tier then 1 else 2) * 100 + index })
	end
	table.sort(order, function(a, b)
		return a.rank < b.rank
	end)
	for position, entry in order do
		local line = entry.line
		local track = line.track
		local card = Ui.surface(track.id, UDim2.new(), list)
		card.LayoutOrder = position
		if line.ready then
			Ui.stroke(card, GOLD, 2.5, 0)
		end
		local medalColor = if line.claimed > 0 then Achievements.TIER_COLORS[line.claimed] else Theme.color.surfaceHigh
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.Size = UDim2.fromOffset(62, 62)
		icon.Position = UDim2.fromOffset(12, 12)
		icon.BackgroundColor3 = TRACK
		icon.Parent = card
		Ui.corner(icon, 31)
		Ui.stroke(icon, medalColor, 3, 0)
		local image = Icons.image(icon, Stats.byId[track.stat].icon, UDim2.fromScale(0.9, 0.9))
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		local name = Ui.label("Name", card, UDim2.new(1, -200, 0, 24), 19, Theme.font.display)
		name.Position = UDim2.fromOffset(86, 8)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = track.name
		local medals = Ui.frame("Medals", UDim2.fromOffset(110, 18), card)
		medals.Position = UDim2.fromOffset(86, 34)
		Ui.list(medals, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		for index = 1, #track.tiers do
			local medal = Instance.new("Frame")
			medal.Name = `Medal{index}`
			medal.Size = UDim2.fromOffset(16, 16)
			medal.LayoutOrder = index
			medal.BackgroundColor3 = if index <= line.claimed then Achievements.TIER_COLORS[index] else TRACK
			medal.BorderSizePixel = 0
			medal.Parent = medals
			Ui.corner(medal, 8)
			Ui.stroke(medal, Achievements.TIER_COLORS[index], 1.5, if index <= line.claimed then 0 else 0.5)
		end
		local goal = Ui.label("Goal", card, UDim2.new(1, -200, 0, 20), 14, Theme.font.bodyBold)
		goal.Position = UDim2.fromOffset(86, 56)
		goal.TextXAlignment = Enum.TextXAlignment.Left
		goal.TextColor3 = Theme.color.textDim
		goal.TextTruncate = Enum.TextTruncate.AtEnd
		goal.TextWrapped = false
		if line.tier then
			local tierIndex = line.claimed + 1
			goal.Text = `{Achievements.TIER_NAMES[tierIndex]}: {Stats.goal(track.stat, line.tier.target)}`
			local progressBar = bar(card, UDim2.new(1, -212, 0, 16), line.progress / line.tier.target, Achievements.TIER_COLORS[tierIndex],
				`{Stats.amount(track.stat, math.min(line.progress, line.tier.target))} / {Stats.amount(track.stat, line.tier.target)}`)
			progressBar.Position = UDim2.fromOffset(86, 82)
			local reward = Ui.label("Reward", card, UDim2.fromOffset(100, 40), 13, Theme.font.bodyBold)
			reward.AnchorPoint = Vector2.new(1, 0)
			reward.Position = UDim2.new(1, -12, 0, 10)
			reward.TextXAlignment = Enum.TextXAlignment.Right
			reward.TextColor3 = GOLD
			reward.Text = (rewardText(line.tier.reward):gsub(" %+ ", "\n+ "))
			local claim = Ui.button(if line.ready then "Claim" else "Not yet", card, function()
				if line.ready then
					hud.callbacks.onProgress({ type = "ClaimAchievement", track = track.id })
				end
			end, if line.ready then "accent" else "disabled")
			claim.Size = UDim2.fromOffset(100, 40)
			claim.AnchorPoint = Vector2.new(1, 1)
			claim.Position = UDim2.new(1, -12, 1, -10)
			Ui.setTextSize(claim, 16)
		else
			goal.Text = "Every medal won!"
			goal.TextColor3 = Achievements.TIER_COLORS[5]
		end
	end
end

-- Empire Tree --------------------------------------------------------------------------------------

local function renderTree(hud: any, content: Frame, data: Progress.Data)
	local state: TreeView.ViewState = hud.treeState
	local claimedCount = Progress.treeClaimed(data)

	local top = Ui.frame("Top", UDim2.new(1, 0, 0, 34), content)
	local summary = Ui.label("Summary", top, UDim2.new(1, -330, 1, 0), 16, Theme.font.bodyBold)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextColor3 = Theme.color.textDim
	summary.Text = `{claimedCount} of {#Tree.NODES} claimed · drag to look around`
	Icons.labelled(top, "Tree", 26, summary)
	local tools = Ui.frame("Tools", UDim2.fromOffset(320, 34), top)
	tools.AnchorPoint = Vector2.new(1, 0)
	tools.Position = UDim2.fromScale(1, 0)
	Ui.list(tools, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	local mapHolder = Ui.frame("MapHolder", UDim2.new(1, -290, 1, -42), content)
	mapHolder.Position = UDim2.fromOffset(0, 42)
	local scroll = TreeView.build(mapHolder, data, state, function(nodeId)
		state.selected = nodeId
		hud:render()
	end)

	local function tool(text: string, order: number, width: number, onClick: () -> ())
		local button = Ui.button(text, tools, onClick, "secondary")
		button.Size = UDim2.fromOffset(width, 32)
		button.LayoutOrder = order
		Ui.setTextSize(button, 15)
	end
	tool("−", 1, 40, function()
		TreeView.zoom(state, 1 / 1.25, TreeView.window(scroll))
		hud:render()
	end)
	tool("+", 2, 40, function()
		TreeView.zoom(state, 1.25, TreeView.window(scroll))
		hud:render()
	end)
	tool("Next goal", 3, 120, function()
		-- The first node ready to claim, else the first one open.
		local target: string? = nil
		for _, node in Tree.NODES do
			local nodeState = Progress.node(data, node.id)
			if nodeState == "Ready" then
				target = node.id
				break
			elseif nodeState == "Active" and not target then
				target = node.id
			end
		end
		if target then
			state.selected = target
			TreeView.focus(state, target, TreeView.window(scroll))
			hud:render()
		end
	end)
	tool("Centre", 4, 90, function()
		TreeView.focus(state, Tree.ROOT, TreeView.window(scroll))
		hud:render()
	end)

	-- The selected node's card.
	local selected = Tree.byId[state.selected or ""] or Tree.byId[Tree.ROOT]
	local card = Ui.surface("Node", UDim2.new(0, 278, 1, -42), content)
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, 0, 0, 42)
	local branch = if selected.branch then Tree.branchById[selected.branch] else nil
	local color = if branch then branch.color else GOLD
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.new(1, 0, 0, 34)
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.Parent = card
	Ui.corner(band, Theme.radius.surface)
	local branchName = Ui.label("Branch", band, UDim2.fromScale(1, 1), 17, Theme.font.display)
	branchName.TextColor3 = Theme.color.ink
	branchName.Text = if branch then string.upper(branch.name) .. (if selected.tip then " · FINALE" else "") else "THE START"
	local blurb = Ui.label("Blurb", card, UDim2.new(1, -20, 0, 34), 13, Theme.font.body)
	blurb.Position = UDim2.fromOffset(10, 38)
	blurb.TextColor3 = Theme.color.textDim
	blurb.Text = if branch then branch.blurb else "Play your first game to open all six branches."

	local nodeState, progress, target = Progress.node(data, selected.id)
	local art = Ui.frame("Art", UDim2.new(1, 0, 0, 128), card)
	art.Position = UDim2.fromOffset(0, 74)
	if selected.reward.item then
		ItemArt.build(art, selected.reward.item, UDim2.fromScale(1, 1))
	else
		local glyph = Ui.label("Glyph", art, UDim2.fromScale(1, 1), 70, Theme.font.display)
		glyph.Text = ""
		local image = Icons.image(art, if selected.reward.key then "Key" else "Coins", UDim2.fromScale(1, 1))
		image.Name = "RewardIcon"
	end
	local rewardRow = rewardChips(card, selected.reward, 15)
	rewardRow.Position = UDim2.fromOffset(0, 206)
	if selected.reward.item then
		local item = Catalog.byId[selected.reward.item]
		local kind = Ui.label("Kind", card, UDim2.new(1, 0, 0, 18), 13, Theme.font.bodyBold)
		kind.Position = UDim2.fromOffset(0, 234)
		kind.TextColor3 = Catalog.RARITY_COLORS[item.rarity]
		kind.Text = `{item.rarity} {Catalog.KIND_NAMES[item.kind]} · challenge exclusive`
	end
	local goal = Ui.label("Goal", card, UDim2.new(1, -20, 0, 50), 19, Theme.font.display)
	goal.Position = UDim2.fromOffset(10, 258)
	goal.Text = Stats.goal(selected.stat, selected.target)
	local status = Ui.label("Status", card, UDim2.new(1, -20, 0, 34), 13, Theme.font.body)
	status.Position = UDim2.fromOffset(10, 334)
	status.TextColor3 = Theme.color.textDim
	if nodeState == "Locked" then
		local parentNode = if selected.parent then Tree.byId[selected.parent] else nil
		status.Text = if parentNode then `Opens when you claim "{Stats.goal(parentNode.stat, parentNode.target)}".` else ""
	elseif nodeState == "Claimed" then
		status.Text = "Claimed."
		status.TextColor3 = Theme.color.moneyUp
	else
		status.Text = "Counts from when this opened."
		local progressBar = bar(card, UDim2.new(1, -20, 0, 20), progress / target, color,
			`{Stats.amount(selected.stat, progress)} / {Stats.amount(selected.stat, target)}`)
		progressBar.Position = UDim2.fromOffset(10, 310)
	end
	local claim = Ui.button(if nodeState == "Ready" then "Claim!" elseif nodeState == "Claimed" then "Claimed" else "Keep playing", card, function()
		if nodeState == "Ready" then
			hud.callbacks.onProgress({ type = "ClaimNode", node = selected.id })
		end
	end, if nodeState == "Ready" then "accent" else "disabled")
	claim.Size = UDim2.new(1, -20, 0, 48)
	claim.AnchorPoint = Vector2.new(0, 1)
	claim.Position = UDim2.new(0, 10, 1, -10)
end

function ChallengesPanel.render(hud: any, frame: Frame)
	local profile = hud.profile
	Ui.clear(frame, function(child)
		return child.Name == "Close"
	end)
	hud.dailyClock = nil
	local heading = Ui.label("Heading", frame, UDim2.new(1, -60, 0, 40), 26, Theme.font.display)
	heading.Position = UDim2.fromOffset(20, 12)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = "Challenges"
	if not profile then
		return
	end
	local data = profile :: any
	local waiting = Progress.claimable(data)

	local tabs = Ui.frame("Tabs", UDim2.fromOffset(600, 40), frame)
	tabs.Position = UDim2.fromOffset(20, 58)
	Ui.list(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local counts = { Daily = waiting.daily, Achievements = waiting.achievements, ["Empire Tree"] = waiting.tree }
	for index, tab in ChallengesPanel.TABS do
		local button = Ui.button(tab, tabs, function()
			hud.challengesTab = tab
			hud:render()
		end, if hud.challengesTab == tab then "accent" else "secondary")
		button.Size = UDim2.fromOffset(170, 38)
		button.LayoutOrder = index
		Ui.setTextSize(button, 16)
		badge(button, counts[tab])
	end

	local content = Ui.frame("Body", UDim2.new(1, -40, 1, -128), frame)
	content.Position = UDim2.fromOffset(20, 110)
	if hud.challengesTab == "Achievements" then
		renderAchievements(hud, content, data)
	elseif hud.challengesTab == "Empire Tree" then
		renderTree(hud, content, data)
	else
		renderDaily(hud, content, data)
	end
end

-- Ticks the daily countdown (called every frame while the lobby is up).
function ChallengesPanel.tick(hud: any)
	local clock = hud.dailyClock
	if clock and clock.Parent then
		clock.Text = `New challenges in {clockText(Dailies.secondsLeft(workspace:GetServerTimeNow()))}`
	end
end

return ChallengesPanel
