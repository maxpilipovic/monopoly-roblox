--!strict
-- How the HUD fits a screen. It is laid out on a fixed canvas and scaled as a whole.

local Layout = {}

Layout.CANVAS = Vector2.new(1280, 720)
Layout.MIN_SCALE = 0.55
Layout.MAX_SCALE = 1.3
Layout.NARROW_WIDTH = 900 -- canvas pixels: below this the side panels can't sit beside the centre ones
Layout.MAX_INSET = 0.4

function Layout.scale(viewport: Vector2): number
	local fit = math.min(viewport.X / Layout.CANVAS.X, viewport.Y / Layout.CANVAS.Y)
	return math.clamp(fit, Layout.MIN_SCALE, Layout.MAX_SCALE)
end

function Layout.isNarrow(viewport: Vector2): boolean
	return viewport.X / Layout.scale(viewport) < Layout.NARROW_WIDTH
end

-- The share of the screen's height the action bar covers, so the camera can keep the board above it.
function Layout.bottomInset(barHeight: number, margin: number, scale: number, viewportHeight: number): number
	if viewportHeight <= 0 then
		return 0
	end
	return math.clamp((barHeight + margin) * scale / viewportHeight, 0, Layout.MAX_INSET)
end

return Layout
