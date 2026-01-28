--- @alias ChatLine (string|Color|Player)[]

--- @class greentext
--- @field cl_chatfilters ConVar
--- @field DeadColor Color
--- @field TeamColor Color
--- @field MessageColor Color
--- @field GreenColor Color
--- @diagnostic disable-next-line: lowercase-global
greentext = {}

greentext.cl_chatfilters = GetConVar("cl_chatfilters")

greentext.DeadColor = Color(255, 30, 40, 255)
greentext.TeamColor = Color(30, 160, 40, 255)
greentext.MessageColor = Color(255, 255, 255, 255)
greentext.GreenColor = Color(170, 215, 50, 255)

--- @param Text string
--- @return ChatLine
function greentext.Apply(Text)
	local Start = string.find(Text, ">")

	if not Start then
		return { Text }
	end

	local Before = string.sub(Text, 1, Start and (Start - 1) or -1)
	local After = string.sub(Text, Start)

	return { Before, greentext.GreenColor, After }
end

-- https://github.com/Facepunch/garrysmod/blob/191339e123edf359d298652ad64cf2cb82c7158f/garrysmod/gamemodes/base/gamemode/cl_init.lua#L142-L182
--- @param Player Player
--- @param Text string
--- @param IsTeam boolean
--- @param IsDead boolean
--- @return boolean|nil
function greentext.OnPlayerChat(Player, Text, IsTeam, IsDead)
	--- @type ChatLine
	local Message = {}

	if IsDead then
		table.insert(Message, greentext.DeadColor)
		table.insert(Message, language.GetPhrase("chat.dead"))
		table.insert(Message, " ")
	end

	if IsTeam then
		table.insert(Message, greentext.TeamColor)
		table.insert(Message, language.GetPhrase("chat.team"))
		table.insert(Message, " ")
	end

	local Typer = IsValid(Player) and Player or nil

	if Typer then
		table.insert(Message, Typer)
	else
		table.insert(Message, language.GetPhrase("chat.console"))
	end

	local Filter = bit.band(greentext.cl_chatfilters:GetInt(), 64) == 0 and TEXT_FILTER_GAME_CONTENT or TEXT_FILTER_CHAT
	local FilteredText = util.FilterText(Text, Filter, Typer)

	table.insert(Message, greentext.MessageColor)
	table.insert(Message, ": ")

	local Greened = greentext.Apply(FilteredText)
	table.Add(Message, Greened)

	chat.AddText(unpack(Message))

	return true
end

hook.Add("OnPlayerChat", "greentext", greentext.OnPlayerChat)
