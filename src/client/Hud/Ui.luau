--!strict
-- The HUD's widget kit: every panel, label and button is built here so the whole game shares one look.

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Ui = {}

export type Style = "primary" | "secondary" | "danger" | "accent" | "disabled"

local STYLES: { [string]: { face: Color3, lip: Color3, text: Color3 } } = {
	primary = { face = Theme.color.primary, lip = Theme.color.primaryLip, text = Theme.color.text },
	secondary = { face = Theme.color.secondary, lip = Theme.color.secondaryLip, text = Theme.color.text },
	danger = { face = Theme.color.danger, lip = Theme.color.dangerLip, text = Theme.color.text },
	accent = { face = Theme.color.accent, lip = Theme.color.accentLip, text = Theme.color.ink },
	disabled = { face = Theme.color.disabled, lip = Theme.color.disabledLip, text = Theme.color.textDim },
}

local LIP_HEIGHT = 4
local PRESS_DEPTH = 3

-- Click handlers by button, so tests (and keyboard shortcuts later) can press one without a mouse.
local handlers: { [TextButton]: () -> () } = {}

function Ui.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.radius.surface)
	corner.Parent = parent
	return corner
end

function Ui.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.color.stroke
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or Theme.strokeTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Ui.padding(parent: Instance, all: number | { top: number?, bottom: number?, left: number?, right: number? }): UIPadding
	local padding = Instance.new("UIPadding")
	local sides = if typeof(all) == "number" then { top = all, bottom = all, left = all, right = all } else all
	padding.PaddingTop = UDim.new(0, sides.top or 0)
	padding.PaddingBottom = UDim.new(0, sides.bottom or 0)
	padding.PaddingLeft = UDim.new(0, sides.left or 0)
	padding.PaddingRight = UDim.new(0, sides.right or 0)
	padding.Parent = parent
	return padding
end

function Ui.list(
	parent: Instance,
	direction: Enum.FillDirection,
	padding: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = vertical or Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

-- A plain transparent container.
function Ui.frame(name: string, size: UDim2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- The navy panel every screen sits on.
function Ui.panel(name: string, size: UDim2, position: UDim2, anchor: Vector2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Theme.color.panel
	frame.BackgroundTransparency = Theme.panelTransparency
	frame.Active = true -- a panel takes the clicks on it; nothing underneath should react
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Ui.corner(frame, Theme.radius.panel)
	Ui.stroke(frame)
	-- A touch lighter at the top, so panels read as lit from above rather than flat.
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 210, 228))
	gradient.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	return frame
end

-- A raised block inside a panel.
function Ui.surface(name: string, size: UDim2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundColor3 = Theme.color.surface
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Ui.corner(frame, Theme.radius.surface)
	return frame
end

function Ui.label(name: string, parent: Instance, size: UDim2, textSize: number, font: Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = font or Theme.font.bodyBold
	label.TextSize = textSize
	label.TextColor3 = Theme.color.text
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

-- The button's coloured face (the TextButton itself is the darker lip under it).
function Ui.face(button: TextButton): Frame
	return button:FindFirstChild("Face") :: Frame
end

function Ui.setStyle(button: TextButton, style: Style)
	local colors = STYLES[style]
	button.BackgroundColor3 = colors.lip
	local face = Ui.face(button)
	face.BackgroundColor3 = colors.face
	face:SetAttribute("Rest", colors.face);
	(face:FindFirstChild("Text") :: TextLabel).TextColor3 = colors.text
	button:SetAttribute("Style", style)
end

-- Changes what a button says (its Text property mirrors it, for anything that reads buttons by text).
function Ui.setText(button: TextButton, text: string)
	button.Text = text;
	(Ui.face(button):FindFirstChild("Text") :: TextLabel).Text = text
end

function Ui.setTextSize(button: TextButton, size: number)
	(Ui.face(button):FindFirstChild("Text") :: TextLabel).TextSize = size
end

-- A chunky button: a coloured face sitting on a darker lip; it lightens under the pointer and
-- sinks onto the lip while held.
function Ui.button(text: string, parent: Instance, onClick: () -> (), style: Style?): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.Size = UDim2.fromOffset(150, 44)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Text = text
	button.TextTransparency = 1 -- the face's label draws it; Text is kept for lookups
	button.Parent = parent
	Ui.corner(button, Theme.radius.surface)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -LIP_HEIGHT)
	face.BorderSizePixel = 0
	face.Active = false
	face.Parent = button
	Ui.corner(face, Theme.radius.surface)
	local label = Ui.label("Text", face, UDim2.fromScale(1, 1), 18, Theme.font.display)
	label.Text = text
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	Ui.padding(label, { left = 6, right = 6 })

	Ui.setStyle(button, style or "primary")

	local function settle(offset: number, lighten: number)
		local rest = face:GetAttribute("Rest") :: Color3
		TweenService:Create(face, TweenInfo.new(Theme.time.fast), {
			Position = UDim2.fromOffset(0, offset),
			BackgroundColor3 = rest:Lerp(Color3.new(1, 1, 1), lighten),
		}):Play()
	end
	button.MouseEnter:Connect(function()
		settle(0, 0.1)
	end)
	button.MouseLeave:Connect(function()
		settle(0, 0)
	end)
	button.MouseButton1Down:Connect(function()
		settle(PRESS_DEPTH, 0)
	end)
	button.MouseButton1Up:Connect(function()
		settle(0, 0.1)
	end)

	handlers[button] = onClick
	button.Destroying:Connect(function()
		handlers[button] = nil
	end)
	button.Activated:Connect(onClick)
	return button
end

-- Runs a button's click handler, as a click would.
function Ui.press(button: TextButton)
	local handler = handlers[button]
	if handler then
		handler()
	end
end

export type ChipState = "normal" | "selected" | "disabled"

-- A deed as a chip: its set's colour down the left edge and its name; a gold outline and a tick
-- when picked, dimmed when it can't be used. With no handler it's only a label.
function Ui.chip(text: string, parent: Instance, color: Color3?, state: ChipState, onClick: (() -> ())?): TextButton
	local chip = Instance.new("TextButton")
	chip.Name = text
	chip.Size = UDim2.new(1, 0, 0, 32)
	chip.AutoButtonColor = false
	chip.Active = onClick ~= nil
	chip.BorderSizePixel = 0
	chip.BackgroundColor3 = if state == "selected" then Theme.color.surfaceHigh
		elseif state == "disabled" then Theme.color.disabled
		else Theme.color.secondary
	chip.Text = text
	chip.TextTransparency = 1 -- the label draws it; Text is kept for lookups
	chip.Parent = parent
	chip:SetAttribute("State", state)
	Ui.corner(chip, Theme.radius.pill)
	if state == "selected" then
		Ui.stroke(chip, Theme.color.accent, 2, 0)
	else
		Ui.stroke(chip, Theme.color.stroke, 1, 0.9)
	end

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.new(0, 6, 1, -10)
	swatch.Position = UDim2.fromOffset(6, 5)
	swatch.BackgroundColor3 = color or Theme.color.textDim
	swatch.BorderSizePixel = 0
	swatch.Parent = chip
	Ui.corner(swatch, 3)

	local label = Ui.label("Text", chip, UDim2.new(1, -44, 1, 0), 14)
	label.Position = UDim2.fromOffset(18, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextColor3 = if state == "disabled" then Theme.color.textDim else Theme.color.text
	label.Text = text

	if state == "selected" then
		local tick = Ui.dot(chip, Theme.color.accent, 14)
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.new(1, -8, 0.5, 0)
	end

	if onClick then
		handlers[chip] = onClick
		chip.Destroying:Connect(function()
			handlers[chip] = nil
		end)
		chip.Activated:Connect(onClick)
	end
	return chip
end

-- A small rounded tag: "YOU", "JAIL", "2/3".
function Ui.pill(text: string, parent: Instance, color: Color3, textColor: Color3?): TextLabel
	local pill = Instance.new("TextLabel")
	pill.Name = text
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 20)
	pill.BackgroundColor3 = color
	pill.BorderSizePixel = 0
	pill.FontFace = Theme.font.bodyBold
	pill.TextSize = 12
	pill.TextColor3 = textColor or Theme.color.text
	pill.Text = text
	pill.Parent = parent
	Ui.corner(pill, Theme.radius.pill)
	Ui.padding(pill, { left = 7, right = 7 })
	return pill
end

-- A round token dot in a seat colour.
function Ui.dot(parent: Instance, color: Color3, diameter: number): Frame
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.fromOffset(diameter, diameter)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = parent
	Ui.corner(dot, diameter)
	Ui.stroke(dot, Color3.new(1, 1, 1), 1.5, 0.55)
	return dot
end

local function popScale(frame: GuiObject): UIScale
	local scale = frame:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = frame
	end
	return scale :: UIScale
end

-- Shows a panel with a small pop. Showing one that's already visible does nothing.
function Ui.show(frame: GuiObject)
	if frame.Visible then
		return
	end
	frame.Visible = true
	local scale = popScale(frame)
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(Theme.time.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Hides at once: a hidden panel must never catch a click meant for the board or another panel.
function Ui.hide(frame: GuiObject)
	frame.Visible = false
end

function Ui.setVisible(frame: GuiObject, visible: boolean)
	if visible then
		Ui.show(frame)
	else
		Ui.hide(frame)
	end
end

local DECORATION = { "UIListLayout", "UIGridLayout", "UICorner", "UIStroke", "UIPadding", "UIScale", "UIGradient", "UISizeConstraint" }

-- Destroys a container's content, leaving its layout and decoration (and anything `keep` says to).
function Ui.clear(parent: Instance, keep: ((Instance) -> boolean)?)
	for _, child in parent:GetChildren() do
		if table.find(DECORATION, child.ClassName) or (keep and keep(child)) then
			continue
		end
		child:Destroy()
	end
end

return Ui
