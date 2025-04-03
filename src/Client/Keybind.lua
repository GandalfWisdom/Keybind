local require = require(script.Parent.loader).load(script);
--DEPENDENCIES
local ContextActionService = game:GetService("ContextActionService");
local CheckInput = require("CheckInput");
local Signal = require("Signal");

local Keybind = {};
Keybind.__index = Keybind;
Keybind.ClassName = "Keybind";

--VARIABLES
local HELD_PREFIX = "Held";
local TAP_INTERVAL = 0.25;
Keybind.InputSignal = Signal.new(); --EVENT THAT FIRES WHENEVER A BOUND INPUT IS ACTIVATED

--BIND TABLE TYPE SET
export type BindTable = {
	Button : EnumItem;
	HeldButton : EnumItem;
	RepeatCount : number;
};
--NEW BIND TABLE CONSTRUCTOR
function Keybind.new_bt(key_enum : EnumItem?, held_key_enum : EnumItem?, repeat_count : number?) : BindTable
	return {
		Button = key_enum;
		HeldButton = held_key_enum;
		RepeatCount = repeat_count;	
	};
end;

--=========================================
--Keybind MAIN CONSTRUCTOR AND FUNCTIONS
--=========================================
--[[
	Constructs a new Keybind object.
]]
function Keybind.new(Name : string, Action : string, PCBind : BindTable, GamepadBind : BindTable)
	local self = setmetatable({}, Keybind);
	
	self.Name = Name;
	self.Action = Action;
	self.PCBind = PCBind;
	self.GamepadBind = GamepadBind;
	
	return self;
end;

--===================
--Keybind METHODS
--===================
local bind_table = {};
local tap_count_table = {};
local held_input_table = {};

local current_input_platform = "PCBind";
--[[
	Checks the amount of times action was tapped, if the tap count meets the action's set tap count, then it will return true, else returns false.
]]
function Keybind.tap_check(action_string : string, keycode : EnumItem)
	if not (bind_table[action_string]) then return; end;--CHECKS IF BINDING IS STORED
	--SETS AND CHECKS FOR IF USER IS ON CONSOLE
	if (CheckInput.gamepad(keycode)) then 
		current_input_platform = "GamepadBind"; 
	else
		current_input_platform = "PCBind";
	end;
	
	if not (bind_table[action_string][current_input_platform]["RepeatCount"]) then return true; end; --Returns if the binding does not have a tap count value assigned.
	if (bind_table[action_string][current_input_platform]["RepeatCount"] <= 1) then return true; end; --Returns if the binding only has a repeat count of 1.
	
	if not (tap_count_table[action_string]) then --SETS VALUE IF THERE IS NONE
		tap_count_table[action_string] = {
			["taps"] = 0;
			["last_time"] = os.clock();
		};
	end;
	
	tap_count_table[action_string]["taps"] += 1; --INCREMENT TAP COUNT
	--INTERVAL CHECK
	local currentTime = os.clock();
	if (currentTime - tap_count_table[action_string]["last_time"] > TAP_INTERVAL) then
		tap_count_table[action_string]["taps"] = 1;
		tap_count_table[action_string]["last_time"] = currentTime;
		return false;
	end;
	
	--TAP COUNT CHECK
	if (tap_count_table[action_string]["taps"] >= bind_table[action_string][current_input_platform]["RepeatCount"]) then --CHECK TAP COUNT
		tap_count_table[action_string] = nil; 
		return true; 
	end;
	
	--INCREMENTS VALUE
	tap_count_table[action_string]["last_time"] = currentTime;
	return false;
end;

--[[
	Checks if the bound held key is currently being held, if so it will return true, else it will return false.
]]
function Keybind.held_check(action_string)
	if not (bind_table[action_string]) then return; end; --RETURNS IMMEDIATELY IF BINDING DOES NOT EXIST IN STORED TABLE
	if not (held_input_table[HELD_PREFIX..action_string]) then --CHECKS IF ACTION IS IN HELD ACTIONS TABLE (WITH HELD PREFIX) IN ORDER TO MAKE SURE FURTHER CHECKS ARE NECESSARY, ELSE AN ACTION IS IN HELD ACTIONS IT JUST RETURNS TRUE
		if not (bind_table[action_string][current_input_platform]["HeldButton"]) then  --IF A HELD BUTTON IS NOT SET, RETURN TRUE, ELSE RETURN FALSE
			return true; 
		else
			return false;
		end;
	else
		return true;
	end;
end;

--INPUTS
local function main_input(action_string: string, input_state: EnumItem, input_object : InputObject)
	if (input_state == Enum.UserInputState.Begin) then
		if (Keybind.tap_check(action_string, input_object.KeyCode)) and (Keybind.held_check(action_string)) then --TAP AND HOLD CHECK
			Keybind.InputSignal:Fire(action_string, input_state, input_object);
		end;
	elseif (input_state == Enum.UserInputState.End) or (input_state == Enum.UserInputState.Cancel) then
		Keybind.InputSignal:Fire(action_string, input_state, input_object);
	end;
	return Enum.ContextActionResult.Pass;
end;

local function held_input(action_string: string, input_state: EnumItem, input_object : InputObject)
	if (input_state == Enum.UserInputState.Begin) then
		if not (held_input_table[action_string]) then
			held_input_table[action_string] = true;
		end;
	elseif (input_state == Enum.UserInputState.End) or (input_state == Enum.UserInputState.Cancel) then
		if (held_input_table[action_string]) then
			held_input_table[action_string] = nil;
		end;
	end
	return Enum.ContextActionResult.Pass;
end;

--[[
	Binds Keybind object to ContextActionService.
]]
function Keybind.bind_context_action(action_string: string, binds_main: table, binds_held: table)
	ContextActionService:BindAction(action_string, main_input, false, unpack(binds_main));
	ContextActionService:BindAction(HELD_PREFIX .. action_string, held_input, false, unpack(binds_held));
end;

--[[
	Binds Keybind to ContextActionService and adds the bind's info to the bindStore table.
]]
function Keybind:Bind()
	local binds_main = {};
	local binds_held = {};
	--MAIN BINDS
	table.insert(binds_main, self.PCBind.Button); --PC
	table.insert(binds_main, self.GamepadBind.Button); --Gamepad
	--HELD BINDS
	table.insert(binds_held, self.PCBind.HeldButton); --PC
	table.insert(binds_held, self.GamepadBind.HeldButton); --Gamepad
	
	Keybind.bind_context_action(self.Action, binds_main, binds_held);
	
	bind_table[self.Action] = self:Table(); --PUTS KEYBIND IN TABLE WHEN BOUND
	return self;
end;

--[[
	Unbinds a Keybind, removing it from ContextActionService and the bindStore table.
]]
function Keybind:Unbind()
	ContextActionService:UnbindAction(self.Action);
	
	bind_table[self.Action] = nil;--REMOVES Keybind FROM TABLE WHEN UNBOUND
	return self;
end;

--[[
	Returns Keybind as a table.
]]
function Keybind:Table()
	return {
		Name = self.Name;	
		Action = self.Action;
		PCBind = self.PCBind;
		GamepadBind = self.GamepadBind;
	};
end;

function Keybind:Destroy()
	self:Unbind();
	setmetatable(self, nil);
end;

return Keybind;
