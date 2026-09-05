NOW=100
GetTime=function() return NOW end
date=function() return "test-session" end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
UNITS={player={guid="0x1",name="Hunter",class="HUNTER"},pet={guid="0x2",name="Wolf"},target={guid="0xF1",name="Mob",hostile=true}}
UnitExists=function(u) local v=UNITS[u]; if v then return true,v.guid end end
UnitName=function(u) local v=UNITS[u]; return v and v.name end
UnitClass=function(u) local v=UNITS[u]; return v and v.class,v and v.class end
UnitCanAttack=function(a,b) local v=UNITS[b]; if v then return v.hostile end; return string.find(b or "","^0xF")~=nil end
UnitAffectingCombat=function() return PLAYER_COMBAT end
UnitClassification=function() return "elite" end
UnitIsDead=function() return false end
UnitIsPlayer=function() return false end
UnitBuff=function() return nil end
GetWeaponEnchantInfo=function() end
GetNumPartyMembers=function() return PARTY_COUNT or 0 end
GetNumRaidMembers=function() return 0 end
SendAddonMessage=function() end
GetShapeshiftForm=function() return 1 end
IsAddOnLoaded=function() return false end
getglobal=function(n) return _G[n] end
geterrorhandler=function() return function(e) error(e) end end
seterrorhandler=function(h) ERROR_HANDLER=h end
FRAMES={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:RegisterEvent(k) self.events[k]=true end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetParent(parent) self.parent=parent end
function methods:GetParent() return self.parent end
function methods:GetChildren()
    local result={}
    for _,f in ipairs(FRAMES) do if f.parent==self and f.kind~='Texture' and f.kind~='FontString' then table.insert(result,f) end end
    return unpack(result)
end
function methods:SetPoint(...) self.lastPoint=arg end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:GetWidth() return self.width or 440 end
function methods:GetHeight() return self.height or 260 end
function methods:GetCenter() return 500,400 end
function methods:GetLeft() return 0 end
function methods:GetRight() return 1000 end
function methods:GetTop() return 800 end
function methods:GetBottom() return 0 end
function methods:GetPoint() return "CENTER",UIParent,"CENTER",0,0 end
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetFrameLevel(level) self.frameLevel=level end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or 'MEDIUM' end
function methods:SetFrameStrata(strata) self.strata=strata end
function methods:GetName() return self.name end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:GetStringWidth() return string.len(self.text or "")*6 end
function methods:NumLines() return 0 end
local function noop() end
local mt={__index=function(t,k)
    if methods[k] then return methods[k] end
    if string.find(k,"^Set") or string.find(k,"^Clear") or string.find(k,"^Enable") or string.find(k,"^Disable") or string.find(k,"^Register") or string.find(k,"^Add") or string.find(k,"^Start") or string.find(k,"^Stop") then return noop end
end}
function CreateFrame(kind,name,parent)
    local f=setmetatable({scripts={},events={},shown=true,name=name,parent=parent,kind=kind},mt)
    table.insert(FRAMES,f)
    if name then _G[name]=f end
    return f
end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
UIParent=CreateFrame("Frame","UIParent")
function fire(frame,ev,a,b,c,d)
    event=ev; arg1=a; arg2=b; arg3=c; arg4=d; this=frame
    frame.scripts.OnEvent()
end
function upvalue(fn,name)
    for i=1,100 do local n,v=debug.getupvalue(fn,i); if not n then break end; if n==name then return v end end
    error("missing upvalue "..name)
end
