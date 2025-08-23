--!strict

-- Voxee: Robust wrapper of Roblox's "Translator" localization API
-- 
-- https://github.com/EmeraldSlash/Voxee
--
-- Created by Rio Manson-Hay (@EmeraldSlash)
--
-- Version: 1 (2025-08-23)
--
-- Change Log:
--
-- Version 1: Initial version.

-- Example code (retained-mode + auto-update):
--[[
local vox = Voxee.NewFromPlayer(game.Players.LocalPlayer, "en")
vox.TranslatorCallback = function()
	local result = vox:TranslateObject(game, "I really like to eat fish!")
	print(result.String)
end
--]]

-- Example code (immediate-mode + manual-update):
--[[
local vox = Voxee.NewFromPlayer(game.Players.LocalPlayer, "en", "manual")
game:GetService("RunService").Heartbeat:Connect(function()
	vox:Update(os.clock())
	if vox.TranslatorDirty then
		vox.TranslatorDirty = false
		local result = vox:TranslateObject(game, "I really like to eat fish!")
		print(result.String)
	end
end)
--]]

local Module = {}

local LocalizationService = game:GetService("LocalizationService")

--
-- Exposed API
--

Module.QueryMaxAttempts = 3 -- attempts
Module.QueryAttemptDelay = 1 -- seconds

-- This function can be overridden if you want to log query & API errors 
-- differently.
function Module.LogQuery(Vox: Vox, String: string)
	warn(String)
end
function Module.LogAPI(Vox: Vox, String: string)
	warn(String)
end

export type Vox = {
	
	-- To create a Vox, call one of the following:
	--
	-- Module.NewFromPlayer(Player, SourceLanguageCode)
	-- Module.NewEmpty() -- (then use Vox:Add...() methods to set it up)
	--
	-- Note that both functions take an optional UpdateMode field which defaults 
	-- to "auto" if not specified. See the AutoUpdate and Update methods below 
	-- for more information.
	
	--
	-- Important Fields
	--
	
	-- The translator that is currently active and will be used by the Translator
	-- methods. This corresponds to the translator entry with the highest 
	-- priority. Such a translator is guaranteed to immediately exist in Voxs 
	-- created by Module.FromPlayer or Voxs which have had Vox:AddPlayer() 
	-- called on them. Otherwise, this field may not be set until an async query 
	-- to obtain a translator succeeds. If you want to create a plain Vox with a 
	-- single translator you already have, you can just create an empty Vox and 
	-- directly set this field.
	Translator: Translator?;
	
	-- The following two fields are immediate-mode and retained-mode signalling 
	-- mechanisms for your code to detect when Translator or Translator.LocaleId 
	-- changes. Note that both of these signalling mechanisms will only activate 
	-- once a Translator is available (see Translator field above). Prior to 
	-- then, TranslatorDirty will be false and TranslatorCallback won't ever be 
	-- called.
	--
	-- (immediate-mode) Automatically set to true to signal that something has 
	-- changed. Usage code is responsible for setting to false after it has 
	-- consumed dirty state.
	TranslatorDirty: boolean;
	--
	-- (retained-mode) Called **immediately in the same thread**, without 
	-- spawning, deferring, or pcalling, when a change occurs. This callback is 
	-- for usage code to detect changes and build its own APIs/systems on top of 
	-- the Vox if it wants to.
	TranslatorCallback: ((Vox: Vox)->())?;
	
	--
	-- Important Methods
	--
	
	-- Don't forget to call this when you are no longer using the Vox!
	Destroy: (Vox: Vox)->();
	
	-- Wrapper of Translator:FormatByKey(Key, Args). See TranslatorResult for
	-- more info.
	TranslateKey:
		(Vox: Vox, Key: string, Args: ({[number]: string} | {[string]: string})?)->(TranslateResult);
	
	-- Wrapper of Translator:Translate(Object, String). See TranslatorResult for
	-- more info.
	TranslateObject:
		(Vox: Vox, Object: Instance, String: string)->(TranslateResult);
	
	--
	-- Extra Fields
	--
	
	-- This field will never actually be set, but you can use it to obtain the 
	-- TranslateResult type without having to require this module. e.g.
	--
	-- local result: typeof(Vox.TranslateResult) = Vox:TranslateObject(...)
	--
	TranslateResult: TranslateResult;
	
	-- Used to in TranslateResult to indicate sucess or failure of translate 
	-- operations. Again so that you can obtain these values without requiring
	-- this module.
	GOOD: string;
	FAIL: string;
	
	--
	-- Extra Methods
	--
	
	-- Manually add a query for a Translator corresponding to a player or locale.
	AddQuery: (Vox: Vox, Priority: number, PlayerOrLocale: Player|string)->();
	
	-- Manually add an existing Translator.
	AddTranslator: (Vox: Vox, Priority: number, Translator: Translator)->();
	
	-- Manually: add queries for a Translator corresponding to the player, and a 
	-- fallback of the game's source locale fallback Translator; and immediately 
	-- add a fallback Translator from the player.
	AddPlayer: (Vox: Vox, Player: Player, SourceLanguageCode: string)->();
	
	-- Enable auto-updating queries and entries. There is no need to call this if
	-- the Vox was created with UpdateMode "auto" (which is also the default).
	AutoUpdate: (Vox: Vox)->();
	
	-- Manually update queries and entries. You only need to call these when the 
	-- Vox was created with UpdateMode "manual" and Vox:AutoUpdate() has not been
	-- called.
	Update: (Vox: Vox, Now: number)->(); -- Do both updates in one call.
	UpdateQueries: (Vox: Vox, Now: number)->(); -- Step 1: Update queries
	UpdateEntries: (Vox: Vox)->(); -- Step 2: Update entries
	
	--
	-- Internal fields
	--
	
	-- Incomplete queries to obtain Translators.
	Queries: {TranslatorQuery};
	
	-- Translators which have been obtained, sorted so that highest priority is 
	-- first.
	Entries: {TranslatorEntry};
	EntriesDirty: boolean;
	
	TranslatorConnection: RBXScriptConnection?; -- Watch Translator.LocaleId
	AutoUpdateConnection: RBXScriptConnection?; -- Update on Heartbeat
}

Module.GOOD = "VOX_TRANSLATE_GOOD"
Module.FAIL = "VOX_TRANSLATE_FAIL"

export type TranslateResult = {
	-- Every field of this type will always be set to a usable value, so you can 
	-- use the result without having to worry about error handling if you don't 
	-- care. e.g.
	--
	-- TextLabel.Text = Vox:TranslateKey("text_label_text").String
	
	Success: boolean; -- Success: true, Fail: false 
	String: string; -- Success: the translated string, Fail: Vox.FAIL
	Error: string; -- Success: Vox.GOOD, Fail: the error message (or Vox.FAIL)
}

--
-- Internal types
--

export type TranslatorQuery = {
	Priority: number;
	PlayerOrLocale: Player|string;
	
	Attempts: number;
	LastAt: number;
	Thread: thread?;
	Result: {
		Message: string?; -- provided if there was an error
		Translator: Translator?; -- provided if successful
	}?;
}
export type TranslatorEntry = {
	Priority: number;
	Translator: Translator;
}

--
-- Implementation
--

local function Async_TranslatorQuery(Query: TranslatorQuery)
	local Translator
	
	local Success, Message
	if type(Query.PlayerOrLocale) == "string" then
		Success, Message = pcall(function()
			Translator = LocalizationService:GetTranslatorForLocaleAsync(Query.PlayerOrLocale)
		end)
	elseif
		typeof(Query.PlayerOrLocale) == "Instance" and
		Query.PlayerOrLocale:IsA("Player")
	then
		Success, Message = pcall(function()
			Translator = LocalizationService:GetTranslatorForPlayerAsync(Query.PlayerOrLocale)
		end)
	else
		Success = false
		Message = "[Query] Missing a player or locale to query"
	end
	
	Query.Result = {
		Message =
			if not Success then assert(Message)
			elseif not Translator then "[Query] Did not get a Translator"
			else nil;
		Translator =
			if not Success then nil
			elseif not Translator then nil
			else Translator;
	}
	Query.Thread = nil
end

function Module.Destroy(Vox: Vox)
	if Vox.AutoUpdateConnection then
		Vox.AutoUpdateConnection:Disconnect()
		Vox.AutoUpdateConnection = nil
	end
	if Vox.TranslatorConnection then
		Vox.TranslatorConnection:Disconnect()
		Vox.TranslatorConnection = nil
	end
	table.clear(Vox.Queries)
	-- Vox.Entries is not cleared, to prevent subsequent updates from throwing 
	-- errors.
end

function Module.Update(Vox: Vox, Now: number)
	Module.UpdateQueries(Vox, Now)
	Module.UpdateEntries(Vox)
end

function Module.UpdateQueries(Vox: Vox, Now: number)
	for Index = #Vox.Queries, 1, -1 do
		local Query = Vox.Queries[Index]
		
		while true do
			if Query.Thread then
				break
				
			elseif Query.Result then
				local Result = Query.Result
				Query.Result = nil :: any
				
				if Result.Translator then
					table.remove(Vox.Queries, Index)
					Module.AddTranslator(Vox, Query.Priority, Result.Translator)
					break
					
				else
					Query.LastAt = Now
					Query.Attempts += 1
					
					assert(Result.Message)
					if type(Query.PlayerOrLocale) == "string" then
						Module.LogQuery(Vox, ("Vox translator query failed for locale \"%s\" with error:%s")
							:format(Query.PlayerOrLocale, Result.Message))
						
					elseif
						typeof(Query.PlayerOrLocale) == "Instance" and
						Query.PlayerOrLocale:IsA("Player")
					then
						Module.LogQuery(Vox, ("Vox translator query failed for player with error:\n%s")
							:format(Result.Message))
						
					else
						Module.LogQuery(Vox, ("Vox translator query failed with error:\n%s")
							:format(Result.Message))
					end
					
					if Query.Attempts >= Module.QueryMaxAttempts then
						table.remove(Vox.Queries, Index)
						break
					end
				end
				
			elseif Now < (Query.LastAt + Module.QueryAttemptDelay) then
				break
				
			else
				local Thread = coroutine.create(Async_TranslatorQuery)
				Query.Thread = Thread :: any
				task.spawn(Thread, Query)
			end
		end
	end
end

function Module.UpdateEntries(Vox: Vox)
	if Vox.EntriesDirty then
		Vox.EntriesDirty = false
		table.sort(Vox.Entries, function(A, B)
			return A.Priority > B.Priority
		end)
		local Entry = Vox.Entries[1]
		
		if Vox.Translator ~= Entry.Translator then
			Vox.Translator = Entry.Translator
			
			do
				local Connection = Vox.TranslatorConnection
				if Connection then
					Connection:Disconnect()
					Vox.TranslatorConnection = nil
				end
			end
			local Connection
			Connection = Entry.Translator:GetPropertyChangedSignal("LocaleId"):Connect(function()
				if Connection.Connected then
					Vox.TranslatorDirty = true
					if Vox.TranslatorCallback then
						Vox.TranslatorCallback(Vox)
					end
				end
			end)
			Vox.TranslatorConnection = Connection
			
			Vox.TranslatorDirty = true
			if Vox.TranslatorCallback then
				Vox.TranslatorCallback(Vox)
			end
		end
	end
end

export type UpdateMode =
	| "auto"
	| "manual"

-- UpdateMode defaults to "auto".
function Module.NewEmpty(UpdateMode: UpdateMode?): Vox
	local Vox = {} :: Vox
	
	Vox.Queries = {}
	Vox.Entries = {}
	
	-- WARNING! Vox cannot be used until something is added to it.
	Vox.Translator = nil :: any
	
	Vox.AddQuery = Module.AddQuery
	Vox.AddTranslator = Module.AddTranslator
	Vox.AddPlayer = Module.AddPlayer
	
	Vox.AutoUpdate = Module.AutoUpdate
	Vox.Update = Module.Update
	Vox.UpdateQueries = Module.UpdateQueries
	Vox.UpdateEntries = Module.UpdateEntries
	
	Vox.TranslateKey = Module.TranslateKey
	Vox.TranslateObject = Module.TranslateObject
	
	Vox.FAIL = Module.FAIL
	Vox.GOOD = Module.GOOD
	
	if (not UpdateMode) or (UpdateMode == "auto") then
		Module.AutoUpdate(Vox)
	end
	
	return Vox
end

-- UpdateMode defaults to "auto". SourceLanguageCode is the backup language that
-- should be used if the player's primary Translator fails to load.
function Module.NewFromPlayer(
	Player: Player,
	SourceLanguageCode: string,
	UpdateMode: UpdateMode?
): Vox
	local Vox = Module.NewEmpty(UpdateMode)
	Module.AddPlayer(Vox, Player, SourceLanguageCode)
	return Vox
end

function Module.AddQuery(
	Vox: Vox,
	Priority: number,
	PlayerOrLocale: Player|string
)
	Vox.Queries[#Vox.Queries+1] = {
		Priority = Priority;
		PlayerOrLocale = PlayerOrLocale;
		
		LastAt = -math.huge;
		Attempts = 0;
	}
end
function Module.AddTranslator(
	Vox: Vox,
	Priority: number,
	Translator: Translator
)
	Vox.Entries[#Vox.Entries+1] = {
		Priority = Priority;
		Translator = Translator;
	}
	Vox.EntriesDirty = true
end
function Module.AddPlayer(Vox: Vox, Player: Player, SourceLanguageCode: string)
	Vox.Queries[#Vox.Queries+1] = {
		Priority = 100;
		PlayerOrLocale = Player;
		LastAt = -math.huge;
		Attempts = 0;
	}
	Vox.Queries[#Vox.Queries+1] = {
		Priority = 50;
		PlayerOrLocale = SourceLanguageCode;
		LastAt = -math.huge;
		Attempts = 0;
	}
	local Default = LocalizationService:GetTranslatorForPlayer(Player)
	Vox:AddTranslator(-math.huge, Default)
	-- Update the entries so that the default translator is added immediately and
	-- can be used by subsequent code.
	Vox:UpdateEntries()
end

function Module.TranslateKey(
	Vox: Vox,
	Key: string,
	Args: ({[number]: string} | {[string]: string})?
): TranslateResult
	
	local Result: TranslateResult = {
		Success = false;
		String = Module.FAIL;
		Error = Module.FAIL;
	}
	if not Vox.Translator then
		Module.LogAPI(Vox,
			debug.traceback("Vox is missing a Translator! Did you forget to add one?", 2))
	else
		local Success, String = pcall(
			Vox.Translator.FormatByKey, Vox.Translator, Key, Args)
		if not Success then
			Result.Error = String
		else
			Result.Success = true
			Result.String = assert(String)
		end
	end
	return Result
end

function Module.TranslateObject(
	Vox: Vox,
	Object: Instance,
	String: string
): TranslateResult
	
	local Result: TranslateResult = {
		Success = false;
		String = Module.FAIL;
		Error = Module.FAIL;
	}
	if not Vox.Translator then
		Module.LogAPI(Vox,
			debug.traceback("Vox is missing a Translator! Did you forget to add one?", 2))
	else
		local Success, String = pcall(
			Vox.Translator.Translate, Vox.Translator, Object, String)
		if not Success then
			Result.Error = String
		else
			Result.Success = true
			Result.String = assert(String)
			Result.Error = Module.GOOD
		end
	end
	return Result
end

function Module.AutoUpdate(Vox: Vox)
	if not Vox.AutoUpdateConnection then
		local Connection
		Connection = game:GetService("RunService").Heartbeat:Connect(function()
			if Connection.Connected then
				Vox:Update(os.clock())
			end
		end)
		Vox.AutoUpdateConnection = Connection
	end
end

return Module