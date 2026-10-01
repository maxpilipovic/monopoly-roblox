--!strict
-- The event log, top right: the last few lines, newest at the bottom and brightest.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local LogFeed = {}
LogFeed.__index = LogFeed

LogFeed.MAX_LINES = 8
local OLDEST_FADE = 0.55 -- transparency of the oldest line shown

export type LogFeed = typeof(setmetatable({} :: { frame: Frame, label: TextLabel, lines: { string } }, LogFeed))

function LogFeed.new(parent: Instance): LogFeed
	-- Grows with its lines, so a quiet game doesn't park an empty box over the table.
	local frame = Ui.panel("Log", UDim2.fromOffset(310, 0), UDim2.new(1, -12, 0, 12), Vector2.new(1, 0), parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	Ui.padding(frame, { top = 8, bottom = 10, left = 12, right = 12 })
	local heading = Ui.label("Heading", frame, UDim2.new(1, 0, 0, 16), 12, Theme.font.display)
	heading.Text = "GAME LOG"
	heading.TextColor3 = Theme.color.textDim
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.LayoutOrder = 1
	local label = Ui.label("Lines", frame, UDim2.new(1, 0, 0, 0), 14, Theme.font.body)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.LayoutOrder = 2
	return setmetatable({ frame = frame, label = label, lines = {} }, LogFeed)
end

local function redraw(self: LogFeed)
	local shown = {}
	local count = #self.lines
	for index, line in self.lines do
		-- Older lines fade toward the top so the eye lands on what just happened.
		local fade = OLDEST_FADE * (count - index) / (LogFeed.MAX_LINES - 1)
		table.insert(shown, if fade > 0 then `<font transparency="{string.format("%.2f", fade)}">{line}</font>` else line)
	end
	self.label.Text = table.concat(shown, "\n")
end

-- Adds lines that are already rich text (see LogFormat).
function LogFeed.push(self: LogFeed, richLines: { string })
	for _, line in richLines do
		table.insert(self.lines, line)
	end
	while #self.lines > LogFeed.MAX_LINES do
		table.remove(self.lines, 1)
	end
	redraw(self)
end

function LogFeed.clear(self: LogFeed)
	table.clear(self.lines)
	redraw(self)
end

return LogFeed
