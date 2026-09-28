--!strict
-- Fixed overhead view of the board, fitted to the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)

local BoardCamera = {}

BoardCamera.PITCH = math.rad(60)

function BoardCamera.getOverheadCFrame(focus: Vector3, boardSize: number, fieldOfViewDegrees: number, aspect: number): CFrame
	-- Fit a sphere around the board so every corner is visible from any angle.
	local radius = boardSize / 2 * math.sqrt(2)
	local halfVertical = math.rad(fieldOfViewDegrees) / 2
	local halfHorizontal = math.atan(math.tan(halfVertical) * aspect)
	local distance = radius / math.sin(math.min(halfVertical, halfHorizontal))

	local offset = Vector3.new(0, math.sin(BoardCamera.PITCH), math.cos(BoardCamera.PITCH)) * distance
	return CFrame.lookAt(focus + offset, focus)
end

function BoardCamera.start()
	local camera = workspace.CurrentCamera

	local function apply()
		local viewport = camera.ViewportSize
		local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = BoardCamera.getOverheadCFrame(Layout.ORIGIN.Position, Layout.BOARD_SIZE, camera.FieldOfView, aspect)
	end

	apply()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	-- The default camera scripts reset the camera when a character spawns; re-apply after them.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
end

return BoardCamera
