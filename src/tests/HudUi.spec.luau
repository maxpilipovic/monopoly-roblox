--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Theme)
local Ui = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Ui)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a button is named and labelled by its text, sits on a lip, and runs its handler"] = function()
	local holder = Instance.new("Frame")
	local clicks = 0
	local button = Ui.button("Roll dice", holder, function()
		clicks += 1
	end)
	assert(button:IsA("TextButton"), "a TextButton")
	Expect.equal(button.Name, "Roll dice")
	Expect.equal(button.Text, "Roll dice")
	Expect.equal(button.Parent, holder)
	assert(Ui.face(button), "has a face on its lip")
	Expect.equal(Ui.face(button).BackgroundColor3, Theme.color.primary, "primary by default")
	Expect.equal(button.BackgroundColor3, Theme.color.primaryLip, "lip")
	Ui.press(button)
	Expect.equal(clicks, 1, "handler ran")
	holder:Destroy()
end

tests["setStyle recolours the face and the lip"] = function()
	local holder = Instance.new("Frame")
	local button = Ui.button("Go bankrupt", holder, function() end, "secondary")
	Expect.equal(Ui.face(button).BackgroundColor3, Theme.color.secondary)
	Ui.setStyle(button, "danger")
	Expect.equal(Ui.face(button).BackgroundColor3, Theme.color.danger, "face")
	Expect.equal(button.BackgroundColor3, Theme.color.dangerLip, "lip")
	Ui.setText(button, "Confirm bankruptcy?")
	Expect.equal(button.Text, "Confirm bankruptcy?", "text mirrors the label")
	holder:Destroy()
end

tests["show and hide switch visibility"] = function()
	local frame = Ui.panel("Test", UDim2.fromOffset(100, 100), UDim2.new(), Vector2.zero, Instance.new("Folder"))
	Ui.hide(frame)
	Expect.equal(frame.Visible, false)
	Ui.show(frame)
	Expect.equal(frame.Visible, true)
	local holder = frame.Parent :: Instance
	holder:Destroy()
end

tests["clear removes content but keeps layout and decoration"] = function()
	local frame = Ui.panel("Test", UDim2.fromOffset(100, 100), UDim2.new(), Vector2.zero, Instance.new("Folder"))
	Ui.list(frame, Enum.FillDirection.Vertical, 4)
	Ui.padding(frame, 8)
	Ui.label("Line", frame, UDim2.fromOffset(10, 10), 14)
	Ui.button("Click", frame, function() end)
	local kept = Ui.label("Keep", frame, UDim2.fromOffset(10, 10), 14)
	Ui.clear(frame, function(child)
		return child == kept
	end)
	Expect.equal(frame:FindFirstChild("Line"), nil, "label removed")
	Expect.equal(frame:FindFirstChild("Click"), nil, "button removed")
	assert(frame:FindFirstChild("Keep"), "kept by the filter")
	assert(frame:FindFirstChildOfClass("UIListLayout"), "layout kept")
	assert(frame:FindFirstChildOfClass("UIPadding"), "padding kept")
	assert(frame:FindFirstChildOfClass("UICorner"), "corner kept")
	assert(frame:FindFirstChildOfClass("UIStroke"), "stroke kept")
	local holder = frame.Parent :: Instance
	holder:Destroy()
end

tests["a pill shows its text on its colour"] = function()
	local holder = Instance.new("Frame")
	local pill = Ui.pill("YOU", holder, Theme.color.accent, Theme.color.ink)
	Expect.equal(pill.Text, "YOU")
	Expect.equal(pill.BackgroundColor3, Theme.color.accent)
	Expect.equal(pill.TextColor3, Theme.color.ink)
	holder:Destroy()
end

tests["a chip shows a deed: plain, picked or unavailable"] = function()
	local holder = Instance.new("Frame")
	local clicks = 0
	local function click()
		clicks += 1
	end
	local plain = Ui.chip("Boardwalk", holder, Color3.fromRGB(0, 114, 187), "normal", click)
	Expect.equal(plain.Text, "Boardwalk", "text mirrored for lookups")
	Expect.equal(plain.Name, "Boardwalk")
	Expect.equal(plain:GetAttribute("State"), "normal")
	Expect.equal((plain:FindFirstChild("Swatch") :: Frame).BackgroundColor3, Color3.fromRGB(0, 114, 187))
	Expect.equal(plain:FindFirstChild("Tick"), nil, "no tick until picked")
	Ui.press(plain)
	Expect.equal(clicks, 1)

	local picked = Ui.chip("Park Place", holder, nil, "selected", click)
	assert(picked:FindFirstChild("Tick"), "a tick when picked")
	Expect.equal((picked:FindFirstChildOfClass("UIStroke") :: UIStroke).Color, Theme.color.accent, "gold outline")

	local off = Ui.chip("Reading Railroad", holder, nil, "disabled", click)
	Expect.equal(off:GetAttribute("State"), "disabled")
	Ui.press(off)
	Expect.equal(clicks, 2, "the caller decides what a click on a disabled chip does")

	local static = Ui.chip("Short Line", holder, nil, "normal", nil)
	Ui.press(static)
	Expect.equal(clicks, 2, "a chip without a handler does nothing")
	holder:Destroy()
end

return tests
