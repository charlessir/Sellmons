loadstring(game:HttpGet("https://raw.githubusercontent.com/charlessir/Sellmons/refs/heads/main/index.lua"))()

local queue =
	queue_on_teleport or
	queueteleport or
	queuonteleport

if queue then
	queue([[
		repeat task.wait() until game:IsLoaded()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/charlessir/Sellmons/refs/heads/main/index.lua"))()
	]])
end
