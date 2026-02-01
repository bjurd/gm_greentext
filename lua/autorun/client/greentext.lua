--- @alias ChatLine (string|Color|Player)[]
--- @alias PrefixCallback fun(Typer: Player, IsTeam: boolean, IsDead: boolean): ChatLine|nil
--- @alias TyperCallback fun(Typer: Player): ChatLine|nil
--- @alias PreFilterCallback fun(Typer: Player, Text: string): ChatLine|nil
--- @alias PostFilterCallback fun(Typer: Player, FilteredText: string): ChatLine|nil
--- @alias AddTextCallback fun(Typer: Player, Message: ChatLine): ChatLine|nil

--- @class greentext
--- @field cl_chatfilters ConVar
--- @field DeadColor Color
--- @field TeamColor Color
--- @field MessageColor Color
--- @field GreenColor Color
--- @field Support greentextSupport
--- @diagnostic disable-next-line: lowercase-global
greentext = {}

greentext.cl_chatfilters = GetConVar("cl_chatfilters")

greentext.DeadColor = Color(255, 30, 40, 255)
greentext.TeamColor = Color(30, 160, 40, 255)
greentext.MessageColor = Color(255, 255, 255, 255)
greentext.GreenColor = Color(170, 215, 50, 255)



--- @param Text string
--- @return ChatLine|nil
function greentext.Apply(Text)
	local Start = string.find(Text, ">")

	if not Start then
		return nil
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
	local Support = greentext.Support

	--- @type ChatLine
	local Message = {}

	if not Support:RunCallbacks(Message, "PrePrefixes", Player, IsTeam, IsDead) then
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
	end
	Support:RunCallbacks(Message, "PostPrefixes", Player, IsTeam, IsDead)

	local Typer = IsValid(Player) and Player or nil

	if not Support:RunCallbacks(Message, "PreTyper", Typer) then
		if Typer then
			table.insert(Message, Typer)
		else
			table.insert(Message, language.GetPhrase("chat.console"))
		end
	end
	Support:RunCallbacks(Message, "PostTyper", Typer)

	Support:RunCallbacks(Message, "PreFilter", Typer, Text) -- TODO: These need more control

	local Filter = bit.band(greentext.cl_chatfilters:GetInt(), 64) == 0 and TEXT_FILTER_GAME_CONTENT or TEXT_FILTER_CHAT
	local FilteredText = util.FilterText(Text, Filter, Typer)

	Support:RunCallbacks(Message, "PostFilter", Typer, FilteredText)

	table.insert(Message, greentext.MessageColor)
	table.insert(Message, ": ")

	if not Support:RunCallbacks(Message, "PreAddText", Typer, Message) then
		table.insert(Message, FilteredText)
	end

	chat.AddText(unpack(Message))

	return true
end
hook.Add("OnPlayerChat", "greentext", greentext.OnPlayerChat)



-- yay addon support yaaaay

--- @class greentextSupport
--- @field PrePrefixes PrefixCallback[]
--- @field PostPrefixes PrefixCallback[]
--- @field PreTyper TyperCallback[]
--- @field PostTyper TyperCallback[]
--- @field PreFilter PreFilterCallback[]
--- @field PostFilter PostFilterCallback[]
--- @field PreAddText AddTextCallback[]
local Support = {
	PrePrefixes = {},
	PostPrefixes = {},
	PreTyper = {},
	PostTyper = {},
	PreFilter = {},
	PostFilter = {},
	PreAddText = {}
}
greentext.Support = Support

--- @param Callbacks (fun(...: any): ChatLine|nil)[]
--- @param ... any
--- @return ChatLine|nil
function Support:RunCallbackTable(Callbacks, ...)
	local Count = #Callbacks

	for i = 1, Count do
		local Result = Callbacks[i](...)

		if Result ~= nil then
			return Result
		end
	end
end

--- @param Message ChatLine
--- @param ListName string
--- @param ... any
--- @return boolean
function Support:RunCallbacks(Message, ListName, ...)
	local Result = self:RunCallbackTable(self[ListName], ...)

	if Result ~= nil then
		table.Add(Message, Result)
		return true
	end

	return false
end

--- @param ListName string
--- @param Callback fun(...: any): ChatLine|nil
function Support:AddLine(ListName, Callback)
	table.insert(self[ListName], Callback)
end



-- Add ourselves into support
do
	local CurrentMessage = ""

	Support:AddLine("PostFilter", function(Typer, FilteredText)
		--- @cast Typer Player
		--- @cast FilteredText string

		CurrentMessage = FilteredText
	end)

	Support:AddLine("PreAddText", function(Typer, Message)
		--- @cast Typer Player
		--- @cast Message ChatLine

		return greentext.Apply(CurrentMessage)
	end)
end



hook.Remove("PostGamemodeLoaded", "aTags_chat")
hook.Add("PostGamemodeLoaded", "greentext:Support:ATags", function()
	if _G.aTags then
		--- @class _G
		--- @field aTags table



		-- For god knows what reason ATags has a PostGamemodeLoaded AND a timer.Simple
		-- to add the hooks...
		hook.Remove("OnPlayerChat", "ATAG_ChatTags")
		timer.Create("FuckATags", 0.1, 10, function()
			hook.Remove("OnPlayerChat", "ATAG_ChatTags")
		end)



		Support:AddLine("PostPrefixes", function(Typer, IsTeam, IsDead)
			--- @cast Typer Player
			--- @cast IsTeam boolean
			--- @cast IsDead boolean

			--- @class Player
			--- @field getChatTag function
			if not isfunction(Typer.getChatTag) then
				return
			end

			local Pieces, MessageColor, NameColor = Typer:getChatTag()

			--- @cast Pieces table|nil
			--- @cast MessageColor Color|string|nil
			--- @cast NameColor Color|string|nil

			if not Pieces then
				return
			end

			if #Pieces > 0 then
				--- @type ChatLine
				local Line = {}

				for k, v in pairs(Pieces) do
					table.insert(Line, v.color or color_white)
					table.insert(Line, v.name or "")
				end

				-- TODO: MessageColor
				-- TODO: NameColor

				return Line
			end
		end)
	end
end)
