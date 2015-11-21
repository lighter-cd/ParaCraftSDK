--[[
Title: RemoteWorld
Author(s): LiXizhi
Date: 2014/1/17
Desc: represent a single downloadable remote world
Use Lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Login/RemoteWorld.lua");
local RemoteWorld = commonlib.gettable("MyCompany.Aries.Creator.Game.Login.RemoteWorld");
local world = RemoteWorld.LoadFromHref(url);
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/main.lua");
NPL.load("(gl)script/apps/Aries/Partners/PartnerPlatforms.lua");
NPL.load("(gl)script/apps/Aries/Creator/WorldCommon.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/API/FileDownloader.lua");
local FileDownloader = commonlib.gettable("MyCompany.Aries.Creator.Game.API.FileDownloader");
local WorldCommon = commonlib.gettable("MyCompany.Aries.Creator.WorldCommon")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local MainLogin = commonlib.gettable("MyCompany.Aries.Game.MainLogin");

local RemoteWorld = commonlib.inherit(nil, commonlib.gettable("MyCompany.Aries.Creator.Game.Login.RemoteWorld"));


function RemoteWorld:ctor()
end


function RemoteWorld:Init(remotefile, server, text, revision, icon, author, size, tag)
	if(not server) then
		return;
	end
	self.server = server;
	self.gs_nid, self.ws_id = server:match("^(%d+)%D(%d+)");

	self.remotefile = remotefile or "http://seed.com/TechDemo";
	if(remotefile) then
		-- just in case it is not a real file, but a seed to create the world from. 
		self.seed = remotefile:match("^http://seed.com/(.+)");
	end
	text = text or "";
	revision = revision or "";
	self.revision = revision;
	self.text = text;
	self.revision = revision;
	self.author = author;
	self.size = size;
	self.tag = tag;

	local tooltip = format(L"服务器:%s", server);
	if(revision~="") then
		tooltip = format(L"%s\n版本:%s", tooltip, revision);
	end
	self.tooltip = tooltip;

	if(icon) then
		self.icon = icon
	else
		self:SetIconByText(self.text);
	end

	self.worldpath = nil;

	-- home proxy
	if(server == "self") then
		self.force_nid = System.User.nid; 	
	else
		self.force_nid = System.User.nid; 
	end
	
	return self;
end

local world_icons = {
	"Texture/blocks/items/1000_Tomato.png", 
	"Texture/blocks/items/1001_Wheat.png", 
	"Texture/blocks/items/1002_Blueberry.png", 
	"Texture/blocks/items/1003_Pumpkin.png", 
	"Texture/blocks/items/1004_Strawberry.png", 
	"Texture/blocks/items/1006_Onion.png", 
	"Texture/blocks/items/1007_Watermelon.png", 
	"Texture/blocks/items/1008_Corn.png", 
	"Texture/blocks/items/1009_Sunflower.png", 
	"Texture/blocks/items/1010_Eggplant.png", 
	"Texture/blocks/items/1011_Radish.png", 
	"Texture/blocks/items/1012_Broccoli.png", 
	"Texture/blocks/items/1013_Carrot.png", 
	"Texture/blocks/items/1014_Potato.png", 
	"Texture/blocks/items/1015_Ginger.png", 
	"Texture/blocks/items/1016_Blackberry.png", 
	"Texture/blocks/items/1017_Cucumber.png", 
	"Texture/blocks/items/1018_Spinach.png", 
	"Texture/blocks/items/1019_Sweetpotato.png", 
	"Texture/blocks/items/1020_Rye.png", 
};
-- static function
function RemoteWorld.GetIconFromText(text)
	local index = (mathlib.GetHash(text) % (#world_icons)) + 1
	return world_icons[index];
end

function RemoteWorld:SetIconByText(text)
	self.icon = RemoteWorld.GetIconFromText(text);
end


-- static: get world server record from HTML's A tag's href attr. 
-- sample
-- http://test.com/a.zip#server=1001_1#text=服务器名字
-- http://test.com/a.zip#server=self#text=服务器名字
-- http://test.com/a.zip#server#1001_1#text#服务器名字
function RemoteWorld.LoadFromHref(href, server)
	if(not href) then
		return 
	end
	server = href:match("#server[#=]([^#=]+)") or server;
	if(href and server) then
		local text = href:match("#text[#=]([^#=]+)") or server or "";
		local revision = href:match("#revision[#=]([^#=]+)") or "";
		local author = href:match("#author[#=]([^#=]+)") or "";
		local size = href:match("#size[#=]([^#=]+)") or "";
		local remotefile = href:match("^(http://.*zip)#server[#=]") or href;
		local tag = href:match("#tag[#=]([^#=]+)") or "";
		
		return RemoteWorld:new():Init(remotefile, server, text, revision, nil, author, size, tag);
	end
end

-- @param filename: this is the only required parameter. 
function RemoteWorld.LoadFromLocalFile(filename, server, text, revision, icon, author, size)
	if(not filename) then
		return 
	end
	return RemoteWorld:new():Init("local://"..filename, server or "self", text, revision, icon, author, size);
end

-- compute local file name
function RemoteWorld:ComputeLocalFileName()
	if(self.remotefile) then
		local filename = self.remotefile:match("([^/]+)%.zip$");
		return format("worlds/DesignHouse/userworlds/%s_r%s.zip", filename, self.revision);
	end
end

-- get local filename
function RemoteWorld:GetLocalFileName()
	if(self.localpath) then
		return self.localpath;
	else
		self.localpath = self:ComputeLocalFileName();
		return self.localpath;
	end
end

function RemoteWorld:ClearDownloadState()
	self.FileDownloader = nil;
	self.isFinished = false;
	self.worldpath = nil;
end

function RemoteWorld:RemoveLocalFile()
	if(self:IsDownloaded()) then
		local filename = self:GetLocalFileName();
		if(filename:match("zip$")) then
			LOG.std(nil, "info", "RemoteWorld", "RemoveLocalFile %s", filename);
			ParaIO.DeleteFile(filename);
			self:ClearDownloadState();
			return true;
		else
			_guihelper.MessageBox("not zip file");
		end
	else
		return true;
	end
end

-- instead of downloading, we will generate using seed. 
function RemoteWorld:CreateWorldWithSeed(seed)
	-- TODO:
end


-- @param world: a table containing infor about the remote world. 
-- @param callbackFunc: function (bSucceed) end
function RemoteWorld:DownloadRemoteFile(callbackFunc)
	if(self.seed) then
		self:CreateWorldWithSeed(seed)
	end
	if(self.worldpath) then
		if(callbackFunc) then
			callbackFunc(true)
		end
		return;
	end

	local function OnCallbackFunc(bSuccess, dest)
		if(bSuccess) then
			self.worldpath = dest;
		end
		if(callbackFunc) then
			callbackFunc(bSuccess);
		end
	end

	local src = self.remotefile;
	local dest = self:ComputeLocalFileName();
	
	if(ParaIO.DoesFileExist(dest)) then
		LOG.std(nil, "info", "RemoteWorld", "world %s already exist locally", dest);
		OnCallbackFunc(true, dest);
		return;
	end

	self.FileDownloader = self.FileDownloader or FileDownloader:new();
	self.FileDownloader:Init(L"世界", src, dest, OnCallbackFunc, "access plus 5 mins", true);
end

function RemoteWorld:IsDownloaded()
	return self:GetDownloadPercentage() == 100;
end

-- @return [-1,100]. return -1 if not downloaded. 100 if already downloaded.  
function RemoteWorld:GetDownloadPercentage()
	if(self.isFinished) then
		return 100;
	end
	local filename = self:GetLocalFileName();
	if(filename) then
		if(ParaIO.DoesFileExist(filename)) then	
			self.isFinished = true;
			return 100;
		elseif(self.FileDownloader) then
			local curSize = self.FileDownloader:GetCurrentFileSize()
			local totalSize = self.FileDownloader:GetTotalFileSize()
			if(curSize > 0) then
				return math.floor((curSize / totalSize)*100);
			else
				return 0;
			end
		end
	end
	return -1;
end
