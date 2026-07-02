local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local currentHealth = humanoid.Health

-- 1. Create the Highlight ONCE and keep it DISABLED
local damageHighlight = Instance.new("Highlight")
damageHighlight.Name = "DamageFlash"
damageHighlight.FillColor = Color3.fromRGB(255, 0, 0)
damageHighlight.FillTransparency = 0.2
damageHighlight.OutlineTransparency = 1
damageHighlight.Enabled = false
damageHighlight.Parent = character

local flashTick = 0

humanoid.HealthChanged:Connect(function(newHealth)
	-- Check if health went down (ignoring healing)
	if newHealth < currentHealth and newHealth > 0 then

		-- 2. Turn it on instantly
		damageHighlight.Enabled = true

		-- 3. Track this specific hit so rapid attacks don't cancel out
		flashTick = flashTick + 1
		local currentTick = flashTick

		-- 4. Turn it off cleanly after 0.25 seconds
		task.delay(0.25, function()
			if flashTick == currentTick then
				damageHighlight.Enabled = false
			end
		end)
	end

	-- Update the health tracker
	currentHealth = newHealth
end)