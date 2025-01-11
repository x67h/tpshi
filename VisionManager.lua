-- Server Script (ServerScriptService/VisionManager)

local Players = game:GetService("Players")
local playerRoles = {} -- Store player roles (red, blue, or neutral)
local playerTeammates = {} -- Store player teammates
local playerHighlights = {} -- Store player highlight states

-- Remote event to handle teleportation
local teleportEvent = Instance.new("RemoteEvent")
teleportEvent.Name = "TeleportEvent"
teleportEvent.Parent = game.ReplicatedStorage

-- Remote event to handle unpairing
local unpairEvent = Instance.new("RemoteEvent")
unpairEvent.Name = "UnpairEvent"
unpairEvent.Parent = game.ReplicatedStorage

-- Remote event to set the teammate on the client
local setTeammateEvent = Instance.new("RemoteEvent")
setTeammateEvent.Name = "SetTeammateEvent"
setTeammateEvent.Parent = game.ReplicatedStorage

-- Remote event to set the highlight on the client
local setHighlightEvent = Instance.new("RemoteEvent")
setHighlightEvent.Name = "SetHighlightEvent"
setHighlightEvent.Parent = game.ReplicatedStorage

local teleporterCountdown = workspace:WaitForChild("TeleporterCountdown")
local countdownUI = teleporterCountdown:WaitForChild("CountdownUI")
local tpCountdownLabel = countdownUI:WaitForChild("TpCountdown")

local function setTeammate(player, teammate)
	if teammate then
		local teammateName = teammate.Name
		local teammateRole = playerRoles[teammate]
		playerTeammates[player] = teammate
		setTeammateEvent:FireClient(player, teammateName, teammateRole)
	end
end

local function assignRole(player, role)
	playerRoles[player] = role

	-- Send the role to the client
	local setVisionEvent = game.ReplicatedStorage:WaitForChild("SetVisionEvent")
	setVisionEvent:FireClient(player, role)

	-- Send the highlight data to the client
	local setHighlightEvent = game.ReplicatedStorage:WaitForChild("SetHighlightEvent")
	local visible = playerHighlights[player]
	if visible == nil then
		visible = false
	end
	setHighlightEvent:FireClient(player, role, visible) -- Initially set highlight to invisible
	playerHighlights[player] = visible
end

local function refreshHighlight(player)
	local role = playerRoles[player] or "neutral"
	local setHighlightEvent = game.ReplicatedStorage:WaitForChild("SetHighlightEvent")
	local visible = playerHighlights[player]
	if visible == nil then
		visible = false
	end
	setHighlightEvent:FireClient(player, role, visible)
end

local function onPlayerAdded(player)
	-- Assign a default role (e.g., neutral)
	local role = playerRoles[player] or "neutral"
	assignRole(player, role)

	-- Set initial teleport state to false
	local setTeleportStateEvent = game.ReplicatedStorage:WaitForChild("SetTeleportStateEvent")
	setTeleportStateEvent:FireClient(player, false)

	-- Set the countdown text to "Waiting for players..."
	tpCountdownLabel.Text = "Waiting for players..."
	countdownUI.Enabled = true

	-- Refresh the highlight
	refreshHighlight(player)

	-- Re-set teammate if the player has a teammate
	local teammate = playerTeammates[player]
	if teammate then
		setTeammate(player, teammate)
	end
end

game.Players.PlayerAdded:Connect(onPlayerAdded)

-- Function to handle role toggling from the client
local function toggleRole(player)
	if playerRoles[player] == "red" then
		assignRole(player, "blue")
	elseif playerRoles[player] == "blue" then
		assignRole(player, "red")
	end
end

-- Remote event to communicate with the client
local toggleVisionEvent = Instance.new("RemoteEvent")
toggleVisionEvent.Name = "ToggleVisionEvent"
toggleVisionEvent.Parent = game.ReplicatedStorage

toggleVisionEvent.OnServerEvent:Connect(toggleRole)

-- Remote event to set the vision on the client
local setVisionEvent = Instance.new("RemoteEvent")
setVisionEvent.Name = "SetVisionEvent"
setVisionEvent.Parent = game.ReplicatedStorage

-- Remote event to set the teleport state on the client
local setTeleportStateEvent = Instance.new("RemoteEvent")
setTeleportStateEvent.Name = "SetTeleportStateEvent"
setTeleportStateEvent.Parent = game.ReplicatedStorage

-- Remote event to disable movement on the client
local disableMovementEvent = Instance.new("RemoteEvent")
disableMovementEvent.Name = "DisableMovementEvent"
disableMovementEvent.Parent = game.ReplicatedStorage

-- Remote event to enable movement on the client
local enableMovementEvent = Instance.new("RemoteEvent")
enableMovementEvent.Name = "EnableMovementEvent"
enableMovementEvent.Parent = game.ReplicatedStorage

-- Get teleporter references once
local redTeleporter = workspace:WaitForChild("RedTeleporter")
local blueTeleporter = workspace:WaitForChild("BlueTeleporter")
local redTeleporterTrigger = workspace:WaitForChild("RedTeleporterTrigger")
local blueTeleporterTrigger = workspace:WaitForChild("BlueTeleporterTrigger")
local exitTeleporter = workspace:WaitForChild("ExitTeleporter")

print("Workspace Children:")
for i, child in ipairs(workspace:GetChildren()) do
	print(i, child.Name, child.ClassName)
end

local redPlayersOnPad = {}
local bluePlayersOnPad = {}
local debounce = {}
local triggerDebounce = {} -- Debounce for the trigger
local teleportedPlayers = {}
local recentlyTeleported = {} -- Track players recently teleported by trigger
local teleportDelay = 0.2 -- Delay before teleporting players
local movementDisabled = {} -- Track players with disabled movement
local teleporterDebounce = {} -- Debounce for the teleporters
local teleporterDebounceTime = 0.5 -- Increased debounce time
local triggerTouchDebounce = {} -- Debounce for the trigger touch
local teleportHeightOffset = 0.2 -- Fixed height offset for teleportation
local redTeleporterOccupied = false
local blueTeleporterOccupied = false
local redTeleporterOccupant = nil
local blueTeleporterOccupant = nil
local triggerTouchDebounceTime = 0.2 -- Debounce time for trigger touch
local teleporterTouchDebounce = {} -- Debounce for the teleporters
local teleporterTouchDebounceTime = 0.2 -- Debounce time for the teleporters

local function getCharacterHeight(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		return humanoid.HipHeight * 2
	else
		return 5 -- Default height if humanoid is not found
	end
end

-- Fix the onTeleporterTriggerTouched function
local function onTeleporterTriggerTouched(trigger, otherPart)
	if not trigger or not otherPart then
		warn("Trigger or otherPart is nil")
		return
	end
	if not otherPart.Parent then
		warn("otherPart.Parent is nil")
		return
	end

	local player = Players:GetPlayerFromCharacter(otherPart.Parent)
	if not player then
		warn("Player not found for otherPart.Parent")
		return
	end

	-- Check debounce
	if triggerTouchDebounce[player] then
		return
	end
	triggerTouchDebounce[player] = true

	print("Teleporter Trigger Touched:", trigger.Name, "by", player.Name)

	local character = player.Character
	if not character then
		warn("Character not found for player:", player.Name)
		triggerTouchDebounce[player] = nil
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		warn("HumanoidRootPart not found for character:", character.Name)
		triggerTouchDebounce[player] = nil
		return
	end

	-- Handle teleporter positioning first
	if trigger == redTeleporterTrigger and redTeleporter then
		if not redTeleporterOccupied then
			local characterHeight = playerHeights[player] or getCharacterHeight(character)
			if not characterHeight then characterHeight = 5 end -- Fallback height

			local teleportPosition = redTeleporter.CFrame * CFrame.new(0, characterHeight / 2 + teleportHeightOffset + 0.8 - redTeleporter.Size.Y / 2, 0)
			character:SetPrimaryPartCFrame(teleportPosition)

			redTeleporterOccupied = true
			redTeleporterOccupant = player
			table.insert(redPlayersOnPad, player)
			print("Player added to red pad")

			-- Show exit button and disable movement after teleporting
			task.spawn(function()
				wait(0.1) -- Small delay to ensure teleport is complete
				if player and player.Parent then -- Check if player still exists
					setTeleportStateEvent:FireClient(player, true)
					movementDisabled[player] = true
					disableMovementEvent:FireClient(player)
				end
			end)
		end
	elseif trigger == blueTeleporterTrigger and blueTeleporter then
		if not blueTeleporterOccupied then
			local characterHeight = playerHeights[player] or getCharacterHeight(character)
			if not characterHeight then characterHeight = 5 end -- Fallback height

			local teleportPosition = blueTeleporter.CFrame * CFrame.new(0, characterHeight / 2 + teleportHeightOffset + 0.8 - blueTeleporter.Size.Y / 2, 0)
			character:SetPrimaryPartCFrame(teleportPosition)

			blueTeleporterOccupied = true
			blueTeleporterOccupant = player
			table.insert(bluePlayersOnPad, player)
			print("Player added to blue pad")

			-- Show exit button and disable movement after teleporting
			task.spawn(function()
				wait(0.1) -- Small delay to ensure teleport is complete
				if player and player.Parent then -- Check if player still exists
					setTeleportStateEvent:FireClient(player, true)
					movementDisabled[player] = true
					disableMovementEvent:FireClient(player)
				end
			end)
		end
	end

	-- Check if both pads are occupied
	if #redPlayersOnPad > 0 and #bluePlayersOnPad > 0 then
		teleportPlayers()
	end

	-- Reset debounce after a delay
	task.delay(triggerTouchDebounceTime, function()
		if player and player.Parent then -- Check if player still exists
			triggerTouchDebounce[player] = nil
		end
	end)
end



	-- Check if both pads are occupied
	if #redPlayersOnPad > 0 and #bluePlayersOnPad > 0 then
		teleportPlayers()
	end

	-- Reset debounce after a delay
	task.delay(triggerTouchDebounceTime, function()
		if player and player.Parent then -- Check if player still exists
			triggerTouchDebounce[player] = nil
		end
	end)
end

-- Then modify handlePlayerDeath to not recreate trigger connections
local function handlePlayerDeath(player)
	print("Handling death for player:", player.Name)

	-- Remove from pad tables
	for i, p in ipairs(redPlayersOnPad) do
		if p == player then
			table.remove(redPlayersOnPad, i)
			print("Removed player from red pad")
			break
		end
	end
	for i, p in ipairs(bluePlayersOnPad) do
		if p == player then
			table.remove(bluePlayersOnPad, i)
			print("Removed player from blue pad")
			break
		end
	end

	-- Reset teleporter occupancy
	if redTeleporterOccupant == player then
		redTeleporterOccupied = false
		redTeleporterOccupant = nil
		print("Reset red teleporter occupancy")
	elseif blueTeleporterOccupant == player then
		blueTeleporterOccupied = false
		blueTeleporterOccupant = nil
		print("Reset blue teleporter occupancy")
	end

	-- Clear all debounce states for this player
	teleporterDebounce[player] = nil
	triggerDebounce[player] = nil
	teleporterTouchDebounce[player] = nil
	triggerTouchDebounce[player] = nil
	recentlyTeleported[player] = nil
	teleportedPlayers[player] = nil

	-- Re-enable movement
	movementDisabled[player] = false
	enableMovementEvent:FireClient(player)

	-- Reset teleport state and UI
	setTeleportStateEvent:FireClient(player, false)

	print("Finished handling death for player:", player.Name)
end

local function teleportPlayers()
	if #redPlayersOnPad > 0 and #bluePlayersOnPad > 0 then
		local redPlayer = redPlayersOnPad[1]
		local bluePlayer = bluePlayersOnPad[1]

		-- Recheck if both players are still on the pads
		if table.find(redPlayersOnPad, redPlayer) and table.find(bluePlayersOnPad, bluePlayer) then
			local redCharacter = redPlayer.Character
			local blueCharacter = bluePlayer.Character

			if redCharacter and blueCharacter then
				-- Make the countdown UI visible
				countdownUI.Enabled = true

				local countdownTime = 5
				local countdownCancelled = false
				for i = countdownTime, 1, -1 do
					if not (table.find(redPlayersOnPad, redPlayer) and table.find(bluePlayersOnPad, bluePlayer)) then
						countdownCancelled = true
						break
					end
					tpCountdownLabel.Text = i
					wait(1)
					if not (table.find(redPlayersOnPad, redPlayer) and table.find(bluePlayersOnPad, bluePlayer)) then
						countdownCancelled = true
						break
					end
				end

				if countdownCancelled then
					tpCountdownLabel.Text = "Waiting for players..."
					countdownUI.Enabled = true
					return
				end

				-- Teleport the players to the main map
				local mapSpawn = workspace:FindFirstChild("MapSpawn")
				if mapSpawn then
					local redSpawn = mapSpawn:FindFirstChild("RedSpawn")
					local blueSpawn = mapSpawn:FindFirstChild("BlueSpawn")
					if redSpawn and blueSpawn then
						local redCharacterHeight = getCharacterHeight(redCharacter)
						local blueCharacterHeight = getCharacterHeight(blueCharacter)

						local redTeleportPosition = redSpawn.CFrame * CFrame.new(0, redCharacterHeight / 2 + teleportHeightOffset + 0.8 - redSpawn.Size.Y / 2, 0)
						local blueTeleportPosition = blueSpawn.CFrame * CFrame.new(0, blueCharacterHeight / 2 + teleportHeightOffset + 0.8 - blueSpawn.Size.Y / 2, 0)

						-- Teleport players
						redCharacter.HumanoidRootPart.CFrame = redTeleportPosition
						blueCharacter.HumanoidRootPart.CFrame = blueTeleportPosition
						print("Teleported players to spawn points")

						-- Reset states
						teleportedPlayers[redPlayer] = true
						teleportedPlayers[bluePlayer] = true

						setTeleportStateEvent:FireClient(redPlayer, false)
						setTeleportStateEvent:FireClient(bluePlayer, false)

						-- Reset teleporter occupancy
						redTeleporterOccupied = false
						blueTeleporterOccupied = false
						redTeleporterOccupant = nil
						blueTeleporterOccupant = nil

						-- Clear the player lists
						redPlayersOnPad = {}
						bluePlayersOnPad = {}

						-- Assign roles and set teammates
						assignRole(redPlayer, "red")
						assignRole(bluePlayer, "blue")

						local redTeammate = bluePlayer
						local blueTeammate = redPlayer

						setTeammate(redPlayer, redTeammate)
						setTeammate(bluePlayer, blueTeammate)

						-- Enable highlights
						setHighlightEvent:FireClient(redPlayer, "red", true)
						setHighlightEvent:FireClient(bluePlayer, "blue", true)

						-- Re-enable movement
						movementDisabled[redPlayer] = false
						movementDisabled[bluePlayer] = false

						task.spawn(function()
							wait(0.5) -- Give time for teleport to complete
							print("Enabling movement for players")
							enableMovementEvent:FireClient(redPlayer)
							enableMovementEvent:FireClient(bluePlayer)
						end)

						-- Update UI
						countdownUI.Enabled = true
						tpCountdownLabel.Text = "Waiting for players..."
					end
				end
			end
		end
	end
end

local function onTeleporterTouched(teleporter, otherPart)
	local player = Players:GetPlayerFromCharacter(otherPart.Parent)
	if player then
		if teleporterDebounce[player] then return end
		teleporterDebounce[player] = true
		print("Teleporter Touched:", teleporter.Name, "by", player.Name)
		wait(teleporterDebounceTime)
		teleporterDebounce[player] = nil
	end
end

local function onTeleporterTouchEnded(teleporter, otherPart)
	local player = Players:GetPlayerFromCharacter(otherPart.Parent)
	if player then
		if teleporterTouchDebounce[player] then return end
		teleporterTouchDebounce[player] = true
		print("Teleporter Touch Ended:", teleporter.Name, "by", player.Name)
		wait(teleporterTouchDebounceTime)
		teleporterTouchDebounce[player] = nil
	end
end

if redTeleporter and redTeleporter:IsA("BasePart") then
	print("RedTeleporter found, Parent:", redTeleporter.Parent.Name)
	redTeleporter.Touched:Connect(function(otherPart)
		onTeleporterTouched(redTeleporter, otherPart)
	end)
	redTeleporter.TouchEnded:Connect(function(otherPart)
		onTeleporterTouchEnded(redTeleporter, otherPart)
	end)
else
	warn("RedTeleporter not found in workspace or is not a BasePart.")
end

if blueTeleporter and blueTeleporter:IsA("BasePart") then
	print("BlueTeleporter found, Parent:", blueTeleporter.Parent.Name)
	blueTeleporter.Touched:Connect(function(otherPart)
		onTeleporterTouched(blueTeleporter, otherPart)
	end)
	blueTeleporter.TouchEnded:Connect(function(otherPart)
		onTeleporterTouchEnded(blueTeleporter, otherPart)
	end)
else
	warn("BlueTeleporter not found in workspace or is not a BasePart.")
end

-- Remote event to send character height from client to server
local sendCharacterHeightEvent = Instance.new("RemoteEvent")
sendCharacterHeightEvent.Name = "SendCharacterHeightEvent"
sendCharacterHeightEvent.Parent = game.ReplicatedStorage

local playerHeights = {} -- Store player heights sent from client

local function onTeleporterTriggerEnded(trigger, otherPart)
	local player = Players:GetPlayerFromCharacter(otherPart.Parent)
	if player then
		if triggerTouchDebounce[player] then return end
		triggerTouchDebounce[player] = true
		print("Teleporter Trigger Ended:", trigger.Name, "by", player.Name)
		if trigger == redTeleporterTrigger then
			for i, p in ipairs(redPlayersOnPad) do
				if p == player then
					table.remove(redPlayersOnPad, i)
					break
				end
			end
		elseif trigger == blueTeleporterTrigger then
			for i, p in ipairs(bluePlayersOnPad) do
				if p == player then
					table.remove(bluePlayersOnPad, i)
					break
				end
			end
		end
		wait(triggerTouchDebounceTime)
		triggerTouchDebounce[player] = nil
	end
end

if redTeleporterTrigger and redTeleporterTrigger:IsA("BasePart") then
	print("RedTeleporterTrigger found, Parent:", redTeleporterTrigger.Parent.Name)
	redTeleporterTrigger.Touched:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			onTeleporterTriggerTouched(redTeleporterTrigger, otherPart)
		end
	end)
	redTeleporterTrigger.TouchEnded:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			onTeleporterTriggerEnded(redTeleporterTrigger, otherPart)
		end
	end)
else
	warn("RedTeleporterTrigger not found in workspace or is not a BasePart.")
end

if blueTeleporterTrigger and blueTeleporterTrigger:IsA("BasePart") then
	print("BlueTeleporterTrigger found, Parent:", blueTeleporterTrigger.Parent.Name)
	blueTeleporterTrigger.Touched:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			onTeleporterTriggerTouched(blueTeleporterTrigger, otherPart)
		end
	end)
	blueTeleporterTrigger.TouchEnded:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			onTeleporterTriggerEnded(blueTeleporterTrigger, otherPart)
		end
	end)
else
	warn("BlueTeleporterTrigger not found in workspace or is not a BasePart.")
end

-- Modify the teleport event handler
teleportEvent.OnServerEvent:Connect(function(player, action)
	if action == "ExitTeleporter" then
		onExitTeleporter(player)
	elseif action == "PlayerDied" then
		handlePlayerDeath(player)
	end
end)

-- Also handle player removal when they leave
game.Players.PlayerRemoving:Connect(function(player)
	handlePlayerDeath(player)
end)

local function unpairPlayers(player)
	local teammate = nil
	local playerRole = playerRoles[player]

	-- Find the teammate
	for p, role in pairs(playerRoles) do
		if p ~= player and role == (playerRole == "red" and "blue" or "red") then
			teammate = p
			break
		end
	end

	-- Unassign player role and remove highlight
	local setHighlightEvent = game.ReplicatedStorage:WaitForChild("SetHighlightEvent")
	setHighlightEvent:FireClient(player, "", false)
	playerHighlights[player] = false

	-- Unassign teammate role and remove highlight
	if teammate then
		setHighlightEvent:FireClient(teammate, "", false)
		playerHighlights[teammate] = false
	end

	playerRoles[player] = nil
	if teammate then
		playerRoles[teammate] = nil
	end

	playerTeammates[player] = nil
	if teammate then
		playerTeammates[teammate] = nil
	end

	-- Clear teammate UI
	local setTeammateEvent = game.ReplicatedStorage:WaitForChild("SetTeammateEvent")
	setTeammateEvent:FireClient(player, "", "")
	if teammate then
		setTeammateEvent:FireClient(teammate, "", "")
	end

	-- Assign neutral role
	assignRole(player, "neutral")
	if teammate then
		assignRole(teammate, "neutral")
	end
end

unpairEvent.OnServerEvent:Connect(unpairPlayers)

sendCharacterHeightEvent.OnServerEvent:Connect(function(player, height)
	playerHeights[player] = height
end)

-- Add this to handle teammate info requests
setTeammateEvent.OnServerEvent:Connect(function(player)
	print("Received teammate info request from:", player.Name)
	local teammate = playerTeammates[player]
	if teammate then
		local teammateName = teammate.Name
		local teammateRole = playerRoles[teammate]
		print("Sending teammate info back to client:")
		print("Teammate name:", teammateName)
		print("Teammate role:", teammateRole)
		setTeammateEvent:FireClient(player, teammateName, teammateRole)
	else
		print("No teammate found for player:", player.Name)
	end
end)

-- Fix the onExitTeleporter function
local function onExitTeleporter(player)
	if not player then return end

	print("Exiting teleporter for player:", player.Name)

	-- Re-enable movement first
	movementDisabled[player] = false
	enableMovementEvent:FireClient(player)

	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		-- Teleport to exit
		local characterHeight = getCharacterHeight(character)
		local teleportPosition = exitTeleporter.CFrame * CFrame.new(0, characterHeight / 2 + teleportHeightOffset - exitTeleporter.Size.Y / 2, 0)
		character:SetPrimaryPartCFrame(teleportPosition)

		-- Reset UI
		setTeleportStateEvent:FireClient(player, false)

		-- Clear occupancy
		if redTeleporterOccupant == player then
			redTeleporterOccupied = false
			redTeleporterOccupant = nil
			for i, p in ipairs(redPlayersOnPad) do
				if p == player then
					table.remove(redPlayersOnPad, i)
					break
				end
			end
		elseif blueTeleporterOccupant == player then
			blueTeleporterOccupied = false
			blueTeleporterOccupant = nil
			for i, p in ipairs(bluePlayersOnPad) do
				if p == player then
					table.remove(bluePlayersOnPad, i)
					break
				end
			end
		end

		-- Clear all debounces for this player
		triggerTouchDebounce[player] = nil
		teleporterTouchDebounce[player] = nil
		teleporterDebounce[player] = nil
		recentlyTeleported[player] = nil
	end

	print("Successfully exited teleporter for player:", player.Name)
end