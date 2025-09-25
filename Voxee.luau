--!strict

-- Voxee: Robust wrapper of Roblox's "Translator" localization API
-- 
-- https://github.com/EmeraldSlash/Voxee
--
-- Created by Rio Manson-Hay (@EmeraldSlash)
--
-- Version: 3 (2025-09-25)
--

-------------------------------------------------------------------------------

--
-- Change Log:
--
-- Version 1: Initial version.
--
-- Version 2: Added Vox:WithCallback() and Vox:IsReady(), fixed missing 
-- Vox:Destroy() method, made most Vox methods chainable, improved docs and 
-- error messages.
--
-- Version 3: Made TranslateResult.String return either the user-provided key or
-- the untranslated message when a translation attempt fails, made
-- TranslateResult.Error also return any usage errors related to the module's
-- API, improved error string names, renamed .LogAPI() to .LogUsage(), and
-- added .LogTranslate() to log the errors related to failed translation
-- attempts.
--

-------------------------------------------------------------------------------

-- Example code (retained-mode + auto-update + WithCallback):
--[[
local vox = Voxee.NewFromPlayer(game.Players.LocalPlayer, "en"):WithCallback(function(vox)
	local result = vox:TranslateObject(game, "I really like to eat fish!")
	print(assert(vox.Translator).LocaleId, result.String)
end)
--]]

-- Example code (retained-mode + auto-update):
--[[
local vox = Voxee.NewFromPlayer(game.Players.LocalPlayer, "en")
vox.TranslatorCallback = function()
	local result = vox:TranslateObject(game, "I really like to eat fish!")
	print(assert(vox.Translator).LocaleId, result.String)
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
		print(assert(vox.Translator).LocaleId, result.String)
	end
end)
--]]

-------------------------------------------------------------------------------

local Module = {}

local LocalizationService = game:GetService("LocalizationService")

--
-- Exposed API
--

Module.QueryMaxAttempts = 3 -- attempts
Module.QueryAttemptDelay = 1 -- seconds (or whatever unit your Now params uses)

-- These function can be overridden if you want to log query, translate, & API
-- usage errors differently.
function Module.LogQuery(Vox: Vox, String: string)
	warn(String)
end
function Module.LogTranslate(Vox: Vox, String: string)
	warn(String)
end
function Module.LogUsage(Vox: Vox, String: string)
	warn(String)
end

export type Vox = {
	
	-- To create a Vox, call one of the following:
	--
	-- Module.NewFromPlayer(Player, SourceLanguageCode, UpdateMode?)
	-- Module.NewEmpty(UpdateMode?) -- (then Vox:Add...() methods to set it up)
	--
	-- Note that both functions take an optional UpdateMode parameter which 
	-- defaults to "auto" if not specified. The only other UpdateMode value is 
	-- "manual". See the AutoUpdate and Update methods below for more 
	-- information.
	--
	-- Module.NewFromPlayer() is equivalent to Module.NewEmpty():AddPlayer().
	-- For explanation of the two parameters see comments for AddPlayer below.
	--
	-- But quickly: takes a SourceLanguageCode parameter to indicate 
	-- the backup language that should be used if the player's primary Translator
	-- fails to load. (This will be queried as well, it may not be available 
	-- immediately.)
	
	--
	-- Important Fields
	--
	
	-- The translator that is currently active and will be used by the Translator
	-- methods. This corresponds to the translator entry with the highest 
	-- priority. Such a translator is guaranteed to immediately exist in Voxs 
	-- created by Module.NewFromPlayer or Voxs which have had Vox:AddPlayer() 
	-- called on them. Otherwise, this field may not be set until an async query 
	-- to obtain a Translator succeeds. If you want to create a plain Vox with a 
	-- single Translator that you already have, you can just create an empty Vox 
	-- and directly set this field.
	Translator: Translator?;
	
	-- The following two fields are immediate-mode and retained-mode signalling 
	-- mechanisms for your code to detect when Translator or Translator.LocaleId 
	-- changes i.e. when translated text may have potentially changed. Note that 
	-- both of these signalling mechanisms will only activate once a Translator 
	-- is available (see Translator field above). Prior to then, TranslatorDirty 
	-- will be false and TranslatorCallback won't ever be called.
	--
	-- (immediate-mode) Automatically set to true to signal that something has 
	-- changed. Usage code is responsible for setting to false after it has 
	-- consumed dirty state.
	TranslatorDirty: boolean;
	--
	-- (retained-mode) This callback, provided by usage code, will be called 
	-- **immediately in the same thread**, without spawning, deferring, or 
	-- pcalling, when a change occurs. This enables the usage code to build its 
	-- own APIs/systems on top of the Vox if it wants to. Remember that simply
	-- setting this field won't run the callback if a Translator is already
	-- available; you should check that on your own.
	TranslatorCallback: ((Vox: Vox)->())?;
	
	--
	-- Important Methods
	--
	
	-- Don't forget to call this when you are no longer using the Vox! Also, 
	-- after calling Destroy the Vox is now equivalent to an empty Vox, so it 
	-- can be reused if for some reason you want that.
	Destroy: (Vox: Vox)->(Vox);
	
	-- Returns true if the Vox is ready to start translating. Equivalent to
	-- Vox.Translator ~= nil. This can be used to avoid logging messages when
	-- the Translate methods are called without an available Translator.
	IsReady: (Vox: Vox)->(boolean);
	
	-- Wrapper of Translator:FormatByKey(Key, Args). See TranslateResult for
	-- more info.
	TranslateKey:
		(Vox: Vox, Key: string, Args: ({[number]: string} | {[string]: string})?)->(TranslateResult);
	
	-- Wrapper of Translator:Translate(Object, String). See TranslateResult for
	-- more info.
	TranslateObject:
		(Vox: Vox, Object: Instance, String: string)->(TranslateResult);
	
	-- This is a wrapper for setting "Vox.TranslatorCallback = Callback" which 
	-- will also run the callback (**deferred** to avoid interfering with your 
	-- code) if a Translator is already available. If subsequent code triggers an
	-- immediate callback execution then the deferred thread will be cancelled 
	-- to avoid triggering the callback unnecessarily or out of order. This 
	-- method also returns the Vox so it can be chained.
	WithCallback: (Vox: Vox, Callback: (Vox: Vox)->())->(Vox);
	
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
	ERR_SUCCESS: string;
	ERR_UNKNOWN: string;
	
	--
	-- Extra Methods
	-- (note: all these methods return the Vox so it can be chained)
	--
	
	-- Manually add a query for a Translator corresponding to a player or locale.
	AddQuery: (Vox: Vox, Priority: number, PlayerOrLocale: Player|string)->(Vox);
	
	-- Manually add an existing Translator.
	AddTranslator: (Vox: Vox, Priority: number, Translator: Translator)->(Vox);
	
	-- Adds:
	--
	-- 1) two queries, one for a Translator corresponding to the Player, and the 
	-- other for a fallback of the game's source locale fallback Translator 
	-- (based on the SourceLanguageCode parameter), and
	--
	-- 2) a default fallback Translator for the Player provided by the engine 
	-- which is available to use immediately. So after calling AddPlayer you can
	-- start translating immediately.
	--
	AddPlayer: (Vox: Vox, Player: Player, SourceLanguageCode: string)->(Vox);
	
	-- Enable auto-updating queries and entries. There is no need to call this if
	-- the Vox was created with UpdateMode "auto" (which is also the default).
	AutoUpdate: (Vox: Vox)->(Vox);
	
	-- Manually update queries and entries. You only need to call these when the 
	-- Vox was created with UpdateMode "manual" and Vox:AutoUpdate() has not been
	-- called. Note that the Now parameter can be based on any time source you
	-- like, such as os.clock() or tick(), as this parameter is the only place
	-- where the module obtains information about time.
	Update: (Vox: Vox, Now: number)->(Vox); -- Do both updates in one call.
	UpdateQueries: (Vox: Vox, Now: number)->(Vox); -- Step 1: Update queries
	UpdateEntries: (Vox: Vox)->(Vox); -- Step 2: Update entries
	
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
	DeferredTranslatorCallbackThread: thread?; -- Used by WithCallback method.
}

Module.ERR_SUCCESS = "VOX_ERR_SUCCESS"
Module.ERR_UNKNOWN = "VOX_ERR_UNKNOWN"

export type TranslateResult = {
	-- Every field of this type will always be set to a usable value, so you can 
	-- use the result without having to worry about error handling if you don't 
	-- care. e.g.
	--
	-- TextLabel.Text = Vox:TranslateKey("text_label_text").String
	
	-- Success: The translated string
	-- Fail: The key (TranslateKey) or the untranslated string (TranslateObject)
	String: string;

	-- Success: true
	-- Fail: false
	Success: boolean;

	-- Success: Vox.ERR_SUCCESS
	-- Fail: The error message related to Roblox's API, or the error message
	-- logged due to incorrect usage of the Vox API, or VOX.ERR_UNKNOWN for
	-- unknown errors.
	Error: string;
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

-- After calling Destroy, the Vox is now equivalent to an empty Vox.
function Module.Destroy(Vox: Vox)
	if Vox.AutoUpdateConnection then
		Vox.AutoUpdateConnection:Disconnect()
		Vox.AutoUpdateConnection = nil
	end
	if Vox.TranslatorConnection then
		Vox.TranslatorConnection:Disconnect()
		Vox.TranslatorConnection = nil
	end
	if Vox.DeferredTranslatorCallbackThread then
		coroutine.close(Vox.DeferredTranslatorCallbackThread)
		Vox.DeferredTranslatorCallbackThread = nil
	end
	
	table.clear(Vox.Queries)
	
	Vox.EntriesDirty = false
	table.clear(Vox.Entries)
	
	Vox.TranslatorDirty = false
	Vox.Translator = nil
	
	return Vox
end

function Module.Update(Vox: Vox, Now: number)
	Module.UpdateQueries(Vox, Now)
	Module.UpdateEntries(Vox)
	return Vox
end

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
	return Vox
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
	return Vox
end

export type UpdateMode =
	| "auto"
	| "manual"

-- UpdateMode defaults to "auto".
function Module.NewEmpty(UpdateMode: UpdateMode?): Vox
	local Vox = {} :: Vox
	
	Vox.Queries = {}
	Vox.Entries = {}
	Vox.EntriesDirty = false
	
	-- WARNING! Vox cannot be used until something is added to it.
	Vox.Translator = nil :: any
	Vox.TranslatorDirty = false
	Vox.WithCallback = Module.WithCallback
	
	Vox.AddQuery = Module.AddQuery
	Vox.AddTranslator = Module.AddTranslator
	Vox.AddPlayer = Module.AddPlayer
	
	Vox.AutoUpdate = Module.AutoUpdate
	Vox.Update = Module.Update
	Vox.UpdateQueries = Module.UpdateQueries
	Vox.UpdateEntries = Module.UpdateEntries
	
	Vox.IsReady = Module.IsReady
	Vox.TranslateKey = Module.TranslateKey
	Vox.TranslateObject = Module.TranslateObject
	
	Vox.Destroy = Module.Destroy
	
	Vox.ERR_UNKNOWN = Module.ERR_UNKNOWN
	Vox.ERR_SUCCESS = Module.ERR_SUCCESS
	
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
	return Vox
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
	return Vox
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
	return Vox
end

function Module.WithCallback(
	Vox: Vox,
	Callback: (Vox: Vox)->()
)
	local function NewCallback()
		Vox.DeferredTranslatorCallbackThread = nil
		Callback(Vox)
	end
	Vox.TranslatorCallback = NewCallback
	
	if Vox.DeferredTranslatorCallbackThread then
		coroutine.close(Vox.DeferredTranslatorCallbackThread)
		Vox.DeferredTranslatorCallbackThread = nil
	end
	if Vox.Translator then
		Vox.DeferredTranslatorCallbackThread = coroutine.create(NewCallback)
		task.defer(Vox.DeferredTranslatorCallbackThread :: thread)
	end
	
	return Vox
end

local function GetErrorMessage(Vox)
	local Count = #Vox.Queries
	local Incomplete =
		if Count < 1 then ""
		elseif Count == 1 then "There is 1 incomplete Translator query which you might need to wait for."
		else ("There are %d incomplete Translator queries which you might need to wait for."):format(Count)
	return ("Vox is missing a Translator! You may have forgotten to add them via Vox:AddPlayer(), Vox:AddTranslator(), or Vox:AddQuery().%s"):format(Incomplete)
end

function Module.IsReady(Vox: Vox)
	return Vox.Translator ~= nil
end

function Module.TranslateKey(
	Vox: Vox,
	Key: string,
	Args: ({[number]: string} | {[string]: string})?
): TranslateResult
	
	local Result: TranslateResult = {
		Success = false;
		String = Key;
		Error = Module.ERR_UNKNOWN;
	}
	if not Vox.Translator then
		local ErrorMessage = GetErrorMessage(Vox)
		Module.LogUsage(Vox, debug.traceback(ErrorMessage, 2))
		Result.Error = ErrorMessage
	else
		local Success, String = pcall(
			Vox.Translator.FormatByKey, Vox.Translator, Key, Args)
		if not Success then
			Module.LogTranslate(Vox, String or Module.ERR_UNKNOWN)
			Result.Error = String or Module.ERR_UNKNOWN
		else
			Result.Success = true
			Result.String = assert(String)
			Result.Error = Module.ERR_SUCCESS
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
		String = String;
		Error = Module.ERR_UNKNOWN;
	}
	if not Vox.Translator then
		local ErrorMessage = GetErrorMessage(Vox)
		Module.LogUsage(Vox, debug.traceback(ErrorMessage, 2))
		Result.Error = ErrorMessage
	else
		local Success, String = pcall(
			Vox.Translator.Translate, Vox.Translator, Object, String)
		if not Success then
			Module.LogTranslate(Vox, String or Module.ERR_UNKNOWN)
			Result.Error = String or Module.ERR_UNKNOWN
		else
			Result.Success = true
			Result.String = assert(String)
			Result.Error = Module.ERR_SUCCESS
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
	return Vox
end

return Module