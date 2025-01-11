-- Local Script (StarterPlayer/StarterCharacterScripts/VisionToggle)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local ContextActionService = game:GetService("ContextActionService")

-- Wait for TeleporterUI to be available in PlayerGui (not StarterGui)
local teleporterUI = playerGui:WaitForChild("TeleporterUI")
local exitButton = teleporterUI:WaitForChild("ExitButton")
local teammateLabel = teleporterUI:WaitForChild("Teammate") -- Get the Teammate TextLabel
local unpairButton = teleporterUI:WaitForChild("UnpairButton")

-- Add debug prints to verify UI elements
print("Found UI elements:")
print("TeleporterUI:", teleporterUI)
print("Teammate Label:", teammateLabel)
print("Unpair Button:", unpairButton)
print("Current teammate label text:", teammateLabel.Text)

-- Highlight Logic
local highlights = {}
local teammateName = nil -- Store the teammate's name
local playerRole = nil -- Store the player's role
local teammateCharacter = nil -- Store the teammate's character

local playerTeammates = {} -- Store player teammates
local playerHighlights = {} -- Store player highlight states

local function createHighlight(target, color)
	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 1
	highlight.Parent = target
	highlight.Enabled = false -- Initially disabled
	return highlight
end

local function updateHighlight(target, role, visible)
	print("Client: Updating highlight for", target.Name, "role:", role, "visible:", visible)

	local highlightTarget = target
	if target:IsA("BasePart") then
		highlightTarget = target.Parent
	end

	-- Only apply highlight to the player's character or their teammate's character
	if highlightTarget == character or (teammateCharacter and highlightTarget == teammateCharacter) or role == "" then
		-- Destroy existing highlight if it exists
		if highlights[highlightTarget] then
			highlights[highlightTarget]:Destroy()
			highlights[highlightTarget] = nil
		end

		if not visible then
			return
		end

		local color
		if role == "red" then
			color = Color3.fromRGB(255, 0, 4)
		elseif role == "blue" then
			color = Color3.fromRGB(0, 123, 255)
		else
			return
		end

		local highlight = createHighlight(highlightTarget, color)
		highlights[highlightTarget] = highlight
		highlight.Enabled = visible
	end
end

-- Wait for the TeleportEvent to be created
wait()
local teleportEvent = game.ReplicatedStorage:WaitForChild("TeleportEvent")

exitButton.MouseButton1Click:Connect(function()
	teleportEvent:FireServer("ExitTeleporter")
end)

local setTeleportStateEvent = game.ReplicatedStorage:WaitForChild("SetTeleportStateEvent")

local function disableMovement()
	ContextActionService:BindAction("MoveForward", function() end, false, Enum.KeyCode.W)
	ContextActionService:BindAction("MoveBackward", function() end, false, Enum.KeyCode.S)
	ContextActionService:BindAction("MoveLeft", function() end, false, Enum.KeyCode.A)
	ContextActionService:BindAction("MoveRight", function() end, false, Enum.KeyCode.D)
	ContextActionService:BindAction("Jump", function() end, false, Enum.KeyCode.Space)
end

local function enableMovement()
	print("Client: Enabling movement")
	ContextActionService:UnbindAction("MoveForward")
	ContextActionService:UnbindAction("MoveBackward")
	ContextActionService:UnbindAction("MoveLeft")
	ContextActionService:UnbindAction("MoveRight")
	ContextActionService:UnbindAction("Jump")
	print("Client: Movement enabled")
end

local disableMovementEvent = game.ReplicatedStorage:WaitForChild("DisableMovementEvent")
local enableMovementEvent = game.ReplicatedStorage:WaitForChild("EnableMovementEvent")

disableMovementEvent.OnClientEvent:Connect(function()
	disableMovement()
end)

enableMovementEvent.OnClientEvent:Connect(function()
	print("Client: Received enable movement event")
	enableMovement()
end)

setTeleportStateEvent.OnClientEvent:Connect(function(state)
	print("Client: Received SetTeleportStateEvent, state:", state) -- Added log
	if state then
		exitButton.Visible = true
	else
		exitButton.Visible = false
	end
end)

-- Add this log to check if the event is received initially
print("Client: VisionToggle script initialized")

local setVisionEvent = game.ReplicatedStorage:WaitForChild("SetVisionEvent")

local function updateVision(role)
	local visionParts = workspace:FindFirstChild("VisionParts")
	if visionParts then
		local redParts = visionParts:FindFirstChild("red")
		local blueParts = visionParts:FindFirstChild("blue")

		if redParts and blueParts then
			for _, part in ipairs(redParts:GetChildren()) do
				if part:IsA("BasePart") then
					part.Transparency = (role == "red" or role == "neutral") and 0 or 1
				end
			end
			for _, part in ipairs(blueParts:GetChildren()) do
				if part:IsA("BasePart") then
					part.Transparency = (role == "blue" or role == "neutral") and 0 or 1
				end
			end
		end
	end
	if role == "red" then
		teammateLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Set text color to red
	elseif role == "blue" then
		teammateLabel.TextColor3 = Color3.fromRGB(0, 0, 255) -- Set text color to blue
	elseif role == "neutral" then
		teammateLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Set text color to white
	end
end

setVisionEvent.OnClientEvent:Connect(updateVision)

local setTeammateEvent = game.ReplicatedStorage:WaitForChild("SetTeammateEvent")

local function updateTeammate(teammateNameParam, teammateRole)
	print("Client: Updating teammate UI:", teammateNameParam, "role:", teammateRole)

	-- Re-acquire UI elements if needed
	if not teammateLabel or not teammateLabel.Parent or not unpairButton or not unpairButton.Parent then
		print("Re-acquiring UI elements...")
		local playerGui = player:WaitForChild("PlayerGui")
		local teleporterUI = playerGui:WaitForChild("TeleporterUI")
		teammateLabel = teleporterUI:WaitForChild("Teammate")
		unpairButton = teleporterUI:WaitForChild("UnpairButton")

		-- Reconnect unpair button click event
		unpairButton.MouseButton1Click:Connect(function()
			print("Unpair button clicked")
			local unpairEvent = game.ReplicatedStorage:WaitForChild("UnpairEvent")
			unpairEvent:FireServer()
			print("Unpair event fired to server")
		end)
	end

	-- Update UI
	pcall(function()
		if teammateNameParam and teammateNameParam ~= "" then
			teammateLabel.Text = "Teammate: " .. teammateNameParam
			if teammateRole == "red" then
				teammateLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
			elseif teammateRole == "blue" then
				teammateLabel.TextColor3 = Color3.fromRGB(0, 0, 255)
			end
			unpairButton.Visible = true

			-- Find and update teammate's character
			local teammate = Players:FindFirstChild(teammateNameParam)
			if teammate then
				playerTeammates[player] = teammate
				if teammate.Character then
					teammateCharacter = teammate.Character
					updateHighlight(teammateCharacter, teammateRole, true)
				end

				-- Connect to teammate's CharacterAdded event
				teammate.CharacterAdded:Connect(function(newCharacter)
					teammateCharacter = newCharacter
					updateHighlight(newCharacter, teammateRole, true)
				end)
			end
		else
			-- Clear UI
			teammateLabel.Text = "Teammate: "
			teammateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			unpairButton.Visible = false

			-- Clear all highlights
			if teammateCharacter and highlights[teammateCharacter] then
				highlights[teammateCharacter]:Destroy()
				highlights[teammateCharacter] = nil
			end
			if character and highlights[character] then
				highlights[character]:Destroy()
				highlights[character] = nil
			end
			teammateCharacter = nil
			playerTeammates[player] = nil
		end
	end)
end

setTeammateEvent.OnClientEvent:Connect(function(teammateNameParam, teammateRole)
	print("Received teammate update from server:")
	print("Teammate name:", teammateNameParam)
	print("Teammate role:", teammateRole)

	-- Use the existing updateTeammate function to handle everything
	updateTeammate(teammateNameParam, teammateRole)
end)

local setHighlightEvent = game.ReplicatedStorage:WaitForChild("SetHighlightEvent")

local function onHighlightReceived(role, visible)
	print("Client: Received highlight event, role:", role, "visible:", visible)
	playerRole = role
	playerHighlights[player] = visible
	local character = player.Character
	if character then
		-- Always remove existing highlight first
		if highlights[character] then
			highlights[character]:Destroy()
			highlights[character] = nil
		end

		-- Only create new highlight if we have a role and should be visible
		if role ~= "" and role ~= "neutral" and visible then
			updateHighlight(character, role, visible)
		end
	end
end

setHighlightEvent.OnClientEvent:Connect(onHighlightReceived)

local function onCharacterAdded(newCharacter)
	if newCharacter == player.Character then
		-- Re-apply highlight when the character respawns
		if playerRole and playerRole ~= "neutral" then
			-- Destroy existing highlight if it exists
			if highlights[newCharacter] then
				highlights[newCharacter]:Destroy()
				highlights[newCharacter] = nil
			end

			local color
			if playerRole == "red" then
				color = Color3.fromRGB(255, 0, 4)
			elseif playerRole == "blue" then
				color = Color3.fromRGB(0, 123, 255)
			end

			local highlight = createHighlight(newCharacter, color)
			highlights[newCharacter] = highlight

			local visible = playerHighlights[player]
			if visible == nil then
				visible = false
			end
			highlight.Enabled = visible
		end

		-- Re-apply teammate UI when the character respawns
		if playerTeammates[player] then
			local teammateName = playerTeammates[player].Name
			local teammateRole = playerRole == "red" and "blue" or "red"
			updateTeammate(teammateName, teammateRole)
		end
	end
end

local function onPlayerAdded(newPlayer)
	if newPlayer ~= player then
		newPlayer.CharacterAdded:Connect(onCharacterAdded)
	else
		-- Apply highlight when the player first joins
		local character = player.Character
		if character then
			if playerRole and playerRole ~= "neutral" then
				-- Destroy existing highlight if it exists
				if highlights[character] then
					highlights[character]:Destroy()
					highlights[character] = nil
				end

				local color
				if playerRole == "red" then
					color = Color3.fromRGB(255, 0, 4)
				elseif playerRole == "blue" then
					color = Color3.fromRGB(0, 123, 255)
				end

				local highlight = createHighlight(character, color)
				highlights[character] = highlight

				local visible = playerHighlights[player]
				if visible == nil then
					visible = false
				end
				highlight.Enabled = visible
			end
		end
		player.CharacterAdded:Connect(onCharacterAdded)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Make the TeleporterUI always enabled
teleporterUI.Enabled = true

-- Modify the unpair button connection
unpairButton.MouseButton1Click:Connect(function()
	print("Unpair button clicked")  -- Debug print
	local unpairEvent = game.ReplicatedStorage:WaitForChild("UnpairEvent")
	unpairEvent:FireServer()
	print("Unpair event fired to server")  -- Debug print
end)

-- Set initial state
unpairButton.Visible = false

local redTeleporterTrigger = workspace:FindFirstChild("RedTeleporterTrigger")
local blueTeleporterTrigger = workspace:FindFirstChild("BlueTeleporterTrigger")

local function getCharacterHeight()
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		return humanoid.HipHeight * 2
	else
		return 5 -- Default height if humanoid is not found
	end
end

if redTeleporterTrigger and redTeleporterTrigger:IsA("BasePart") then
	print("RedTeleporterTrigger found, Parent:", redTeleporterTrigger.Parent.Name)
	redTeleporterTrigger.Touched:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			local sendCharacterHeightEvent = game.ReplicatedStorage:WaitForChild("SendCharacterHeightEvent")
			sendCharacterHeightEvent:FireServer(getCharacterHeight())
		end
	end)
end

if blueTeleporterTrigger and blueTeleporterTrigger:IsA("BasePart") then
	print("BlueTeleporterTrigger found, Parent:", blueTeleporterTrigger.Parent.Name)
	blueTeleporterTrigger.Touched:Connect(function(otherPart)
		if otherPart.Parent:IsA("Model") and otherPart.Parent:FindFirstChild("Humanoid") then
			local sendCharacterHeightEvent = game.ReplicatedStorage:WaitForChild("SendCharacterHeightEvent")
			sendCharacterHeightEvent:FireServer(getCharacterHeight())
		end
	end)
end

local function onDied()
	print("Player died, waiting for respawn...")

	-- Tell server player died (add this)
	local teleportEvent = game.ReplicatedStorage:WaitForChild("TeleportEvent")
	teleportEvent:FireServer("PlayerDied")

	-- Wait for new character
	local newCharacter = player.CharacterAdded:Wait()
	print("Player respawned, character:", newCharacter)
	print("Current playerRole:", playerRole)

	-- Re-enable movement in case player died while movement was disabled
	enableMovement()
	-- Reset teleport state
	exitButton.Visible = false

	-- Re-apply own highlight
	if playerRole and playerRole ~= "neutral" then
		print("Creating highlight...")
		local color
		if playerRole == "red" then
			color = Color3.fromRGB(255, 0, 4)
		elseif playerRole == "blue" then
			color = Color3.fromRGB(0, 123, 255)
		end

		-- Create own highlight
		print("Creating new highlight")
		local highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = 1
		highlight.Parent = newCharacter
		highlight.Enabled = true
		highlights[newCharacter] = highlight
		print("Highlight created and enabled")

		-- Request teammate info from server
		local setTeammateEvent = game.ReplicatedStorage:WaitForChild("SetTeammateEvent")
		setTeammateEvent:FireServer() -- Request teammate update from server
	end
end

-- Connect to the current character's Humanoid.Died event
if player.Character then
	local humanoid = player.Character:WaitForChild("Humanoid")
	humanoid.Died:Connect(onDied)
	print("Connected Died event to current character")
end

-- Connect to future characters' Humanoid.Died events
player.CharacterAdded:Connect(function(char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(onDied)
	print("Connected Died event to new character")
end)