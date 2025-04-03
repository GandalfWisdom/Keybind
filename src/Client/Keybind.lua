local require = require(script.Parent.loader).load(script);
--DEPENDENCIES
local cas = game:GetService("ContextActionService");
local CheckInput = require("CheckInput");
local Signal = require("Signal");

local Keybind = {};
Keybind.__index = Keybind;
Keybind.ClassName = "Keybind";

--VARIABLES
local HeldPrefix = "Held";
local tapInterval = 0.25;
Keybind.InputSignal = Signal.new(); --EVENT THAT FIRES WHENEVER A BOUND INPUT IS ACTIVATED

--BIND TABLE TYPE SET
export type BindTable = {
	Button : EnumItem;
	HeldButton : EnumItem;
	RepeatCount : number;	
};
--NEW BIND TABLE CONSTRUCTOR
Keybind.newBT = function(buttonVal : EnumItem?, heldButtonVal : EnumItem?, repeatCountVal : number?) : BindTable
	return {
		Button = buttonVal;
		HeldButton = heldButtonVal;
		RepeatCount = repeatCountVal;	
	};
end;

--==========================
--Keybind MAIN CONSTRUCTOR AND FUNCTIONS
--==========================
local bindStore = {};
local tapCount = {};

local platformBind = "PCBind";
--[[
	Checks the amount of times action was tapped, if the tap count meets the action's set tap count, then it will return true, else returns false.
]]
local function tapCheck(actionName : string, keycode : EnumItem)
	if not (bindStore[actionName]) then return; end;--CHECKS IF BINDING IS STORED
	--SETS AND CHECKS FOR IF USER IS ON CONSOLE
	if (CheckInput.gamepad(keycode)) then 
		platformBind = "GamepadBind"; 
	else
		platformBind = "PCBind";
	end;
	
	if not (bindStore[actionName][platformBind]["RepeatCount"]) then return true; end;
	if (bindStore[actionName][platformBind]["RepeatCount"] <= 1) then return true; end;
	
	
	if not (tapCount[actionName]) then --SETS VALUE IF THERE IS NONE
		tapCount[actionName] = {
			["taps"] = 0;
			["lastTime"] = os.clock();
		};
	end;
	
	tapCount[actionName]["taps"] += 1; --INCREMENT TAP COUNT
	--INTERVAL CHECK
	local currentTime = os.clock();
	if (currentTime - tapCount[actionName]["lastTime"] > tapInterval) then
		tapCount[actionName]["taps"] = 1;
		tapCount[actionName]["lastTime"] = currentTime;
		return false;
	end;
	
	--TAP COUNT CHECK
	if (tapCount[actionName]["taps"] >= bindStore[actionName][platformBind]["RepeatCount"]) then --CHECK TAP COUNT
		tapCount[actionName] = nil; 
		return true; 
	end;
	
	--INCREMENTS VALUE
	tapCount[actionName]["lastTime"] = currentTime;
	return false;
end;

--[[
	Checks if the bound held key is currently being held, if so it will return true, else it will return false.
]]
local function heldCheck(actionName)
	if not (bindStore[actionName]) then return; end; --RETURNS IMMEDIATELY IF BINDING DOES NOT EXIST IN STORED TABLE

	if not (Keybind.heldActions[HeldPrefix..actionName]) then --CHECKS IF ACTION IS IN HELD ACTIONS TABLE (WITH HELD PREFIX) IN ORDER TO MAKE SURE FURTHER CHECKS ARE NECESSARY, ELSE AN ACTION IS IN HELD ACTIONS IT JUST RETURNS TRUE
		if not (bindStore[actionName][platformBind]["HeldButton"]) then  --IF A HELD BUTTON IS NOT SET, RETURN TRUE, ELSE RETURN FALSE
			return true; 
		else
			return false;
		end;
	else
		return true;
	end;
end;


--INPUTS
local function mainInput(actionName, inputState, inputObject : InputObject)
	--print("MAIN INPUT: ", actionName, inputState, inputObject.KeyCode)
	--MODULE CHECK
	--print(bindStore);
	if (inputState == Enum.UserInputState.Begin) then
		if (tapCheck(actionName, inputObject.KeyCode)) and (heldCheck(actionName)) then --TAP AND HOLD CHECK
			Keybind.InputSignal:Fire(actionName, inputState, inputObject);
		end;
	elseif (inputState == Enum.UserInputState.End) or (inputState == Enum.UserInputState.Cancel) then
		Keybind.InputSignal:Fire(actionName, inputState, inputObject);
	end;
	

	return Enum.ContextActionResult.Pass;
end;

Keybind.heldActions = {};
local function heldInput(actionName, inputState, inputObject : InputObject)
	if (inputState == Enum.UserInputState.Begin) then
		if not (Keybind.heldActions[actionName]) then
			Keybind.heldActions[actionName] = true;
		end;
	elseif (inputState == Enum.UserInputState.End) or (inputState == Enum.UserInputState.Cancel) then
		if (Keybind.heldActions[actionName]) then
			Keybind.heldActions[actionName] = nil;
		end;
	end
	
	return Enum.ContextActionResult.Pass;
end;

--CONSTRUCTOR
--[[
	Constructs a new Keybind object.
]]
function Keybind.new(Name : string, ModuleName : string, Action : string, PCBind : BindTable, GamepadBind : BindTable)
	local self = setmetatable({}, Keybind);
	
	self._Name = Name;
	self._ModuleName = ModuleName;
	self._Action = Action;
	self._PCBind = PCBind;
	self._GamepadBind = GamepadBind;
	
	return self;
end;

--===================
--Keybind METHODS
--===================
--[[
	Binds Keybind object to ContextActionService.
]]
local bindCAS = function(action, bindsMain, bindsHeld)
	cas:BindAction(action, mainInput, false, unpack(bindsMain));
	cas:BindAction(HeldPrefix .. action, heldInput, false, unpack(bindsHeld));
end;

--[[
	Binds Keybind to ContextActionService and adds the bind's info to the bindStore table.
]]
function Keybind:Bind()
	local bindsMain = {};
	local bindsHeld = {};
	--MAIN BINDS
	table.insert(bindsMain, self._PCBind.Button); --PC
	table.insert(bindsMain, self._GamepadBind.Button); --Gamepad
	--HELD BINDS
	table.insert(bindsHeld, self._PCBind.HeldButton); --PC
	table.insert(bindsHeld, self._GamepadBind.HeldButton); --Gamepad
	
	bindCAS(self._Action, bindsMain, bindsHeld);
	
	bindStore[self._Action] = self:Table(); --PUTS Keybind IN TABLE WHEN BOUND
	return self;
end;

--[[
	Unbinds a Keybind, removing it from ContextActionService and the bindStore table.
]]
function Keybind:Unbind()
	cas:UnbindAction(self._Action);
	
	bindStore[self._Action] = nil;--REMOVES Keybind FROM TABLE WHEN UNBOUND
	return self;
end;


--[[
	Returns Keybind as a table.
]]
function Keybind:Table()
	return {
		Name = self._Name;	
		ModuleName = self._ModuleName;
		Action = self._Action;
		PCBind = self._PCBind;
		GamepadBind = self._GamepadBind;
	};
end;


--print(Keybind);
return Keybind;
