local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local prefix = "."

local apiKey = "" -- Your Groq API key

-- Function to call Groq
local function askGroq(prompt)
	local success, response = pcall(function()
		return request({
			Url = "https://api.groq.com/openai/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. apiKey
			},
			Body = HttpService:JSONEncode({
				model = "llama-3.3-70b-versatile",

				messages = {
					{
						role = "user",
						content = prompt
					}
				},

				temperature = 0.7,
				max_tokens = 200
			})
		})
	end)

	if success and response and response.Success then
		local data = HttpService:JSONDecode(response.Body)

		if data.choices
			and data.choices[1]
			and data.choices[1].message
			and data.choices[1].message.content then

			return data.choices[1].message.content
		end
	end

	return "Error: Could not fetch response from AI."
end

local function handleCommand(msg)
	local commandTarget = prefix .. "ai "

	if string.sub(msg:lower(), 1, #commandTarget) == commandTarget then
		local prompt = string.sub(msg, #commandTarget + 1)

		if prompt and string.gsub(prompt, " ", "") ~= "" then
			task.spawn(function()
				local aiResponse = askGroq(prompt)

				game.ReplicatedStorage.DefaultChatSystemChatEvents
					.SayMessageRequest:FireServer(aiResponse, "All")
			end)
		end
	end
end

TextChatService.MessageReceived:Connect(function(tbl)
	if not tbl.TextSource then
		return
	end

	local player = Players:GetPlayerByUserId(tbl.TextSource.UserId)

	if not player or player ~= LocalPlayer then
		return
	end

	handleCommand(tbl.Text)
end)
