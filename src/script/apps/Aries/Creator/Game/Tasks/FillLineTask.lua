--[[
Title: Create Line
Author(s): LiXizhi
Date: 2013/1/19
Desc: Replace blocks in the direction specifed until it is blocked by another block or max_radius is reached. 
Support undo/redo
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/FillLineTask.lua");
local task = MyCompany.Aries.Game.Tasks.FillLine:new({blockX = result.blockX,blockY = result.blockY, blockZ = result.blockZ, side = result.side, fill_id=nil, max_radius = 20})
task:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Tasks/UndoManager.lua");
local UndoManager = commonlib.gettable("MyCompany.Aries.Game.UndoManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local Direction = commonlib.gettable("MyCompany.Aries.Game.Common.Direction");

local FillLine = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Task"), commonlib.gettable("MyCompany.Aries.Game.Tasks.FillLine"));

FillLine.max_radius = 20;
FillLine.min_radius = 4;
FillLine.radius = FillLine.min_radius;

function FillLine:ctor()
	self.step = 1;
	self.history = {};
end

function FillLine:Run()
	if(self.blockX and self.side) then
		if(not self.fill_id) then
			-- self.fill_id = GameLogic.GetBlockInRightHand(); 
			self.fill_id = ParaTerrain.GetBlockTemplateByIdx(self.blockX, self.blockY, self.blockZ);
			if(self.fill_id == 0) then
				return;
			end
			self.fill_data = ParaTerrain.GetBlockUserDataByIdx(self.blockX, self.blockY, self.blockZ);
			if(self.fill_data == 0) then
				self.fill_data = nil;
			end
		end
		local block_template = BlockEngine:GetBlock(self.blockX, self.blockY, self.blockZ);

		local side = self.side;
		self.dx, self.dy, self.dz = Direction.GetOffsetBySide(self.side);

		if(block_template and not block_template:canPlaceBlockOnSide(self.blockX+self.dx, self.blockY+self.dy, self.blockZ+self.dz, self.side)) then
			return;
		end

		self.radius = self.min_radius;
		local n;
		for n=1, self.max_radius do
			local block_id = ParaTerrain.GetBlockTemplateByIdx(self.blockX+self.dx*n,self.blockY+self.dy*n,self.blockZ+self.dz*n);
			if(block_id ~= 0) then
				self.max_radius = n;
				if(block_id == self.fill_id) then
					self.radius = n;
				end
				break;
			end
		end

		local tx, ty, tz = BlockEngine:real(self.blockX,self.blockY,self.blockZ);
		GameLogic.PlayAnimation({animationName = "RaiseTerrain",facingTarget = {x=tx, y=ty, z=tz},});

		TaskManager.AddTask(self);
	end	
end

function FillLine:FillLine(x, y, z)
	if(ParaTerrain.GetBlockTemplateByIdx(x,y,z) == self.from_id) then
		self.new_blocks[#(self.new_blocks)+1] = {x,y,z};
		BlockEngine:SetBlock(x,y,z, self.to_id);
	end
end

function FillLine:FrameMove()
	self.step = self.step + 1;

	self.blockX = self.blockX + (self.dx or 0);
	self.blockY = self.blockY + (self.dy or 0);
	self.blockZ = self.blockZ + (self.dz or 0);

	if(ParaTerrain.GetBlockTemplateByIdx(self.blockX,self.blockY,self.blockZ) == 0 and self.step <= self.radius) then
		BlockEngine:SetBlock(self.blockX,self.blockY,self.blockZ, self.fill_id, self.fill_data);
		if(GameLogic.GameMode:CanAddToHistory()) then
			self.history[#(self.history)+1] = {self.blockX,self.blockY,self.blockZ};
		end
	else
		self.finished = true;
		if(GameLogic.GameMode:CanAddToHistory()) then
			if(#(self.history) > 0) then
				UndoManager.PushCommand(self);
			end
		end
	end
end

function FillLine:Redo()
	if(self.blockX and self.fill_id and (#self.history)>0) then
		local _, b;
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], self.fill_id, self.fill_data);
		end
	end
end

function FillLine:Undo()
	if(self.blockX and self.fill_id and (#self.history)>0) then
		local _, b;
		for _, b in ipairs(self.history) do
			BlockEngine:SetBlock(b[1],b[2],b[3], 0);
		end
	end
end
