-- LOCAL MAINTAINER DISPLAY. Not part of the public release.
local D=CAW_DPS_METER

function D.localSyncCounts()
    local raid=GetNumRaidMembers and GetNumRaidMembers() or 0
    local party=GetNumPartyMembers and GetNumPartyMembers() or 0
    local total=raid>0 and raid or party+1
    local known,data=1,0 -- local Caw is known; data counts received remote profiles
    local members={}; local seen={}
    local _,selfGuid=UnitExists("player"); if selfGuid then seen[selfGuid]=true end
    local count=raid>0 and raid or party
    local i
    for i=1,count do
        local unit=(raid>0 and "raid" or "party")..i
        local exists,guid=UnitExists(unit)
        if exists and guid and not seen[guid] then
            seen[guid]=true
            local name=UnitName(unit) or "?"
            local peer=D.threatSyncPeers and D.threatSyncPeers[guid]
            local detected=peer and peer.name==name and GetTime()-peer.time<=45
            local profile=D.talentProfileFor and D.talentProfileFor({guid=guid})
            local available=profile and profile.available
            if detected then known=known+1 end
            if available then data=data+1 end
            table.insert(members,{name=name,detected=detected,available=available,layouts=peer and peer.talentLayouts})
        end
    end
    return known,total,data,math.max(0,total-1),members
end

local function fit(text,label)
    text:SetText(label)
    if not text.GetStringWidth or text:GetStringWidth()<=text:GetWidth() then return end
    while string.len(label)>0 do
        label=string.sub(label,1,-2); text:SetText(label.."...")
        if text:GetStringWidth()<=text:GetWidth() then return end
    end
    text:SetText("...")
end
function D.localSyncFooterLayout(v)
    if not v or v.id~=1 or not v.footerHandle then return end
    local f=D.localSyncStatus
    if not f then
        f=CreateFrame("Frame",nil,v.footerHandle); D.localSyncStatus=f
        f:SetHeight(17); f:SetPoint("BOTTOMLEFT",v.frame,"BOTTOMLEFT",0,1)
        -- Hover regions handle input; the labels remain transparent to the mouse.
        f:EnableMouse(false)
        f.users=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f.talents=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        for _,text in ipairs({f.users,f.talents}) do
            text:SetFont(D.uiFont or "Fonts\\ARIALN.TTF",9); text:SetHeight(12)
            text:SetTextColor(0.82,0.83,0.85); text:SetShadowColor(0,0,0,1); text:SetShadowOffset(1,-1)
        end
        f.users:SetJustifyH("LEFT"); f.talents:SetJustifyH("CENTER")
    end
    local counts=D.localSyncFooterCounts or {D.localSyncCounts()}
    local w=v.frame:GetWidth(); local compact=w<300
    local middle=math.floor(w/2); local middleWidth=compact and 38 or 72
    local rightStart=middle+middleWidth/2+6
    local usersEnd=middle-middleWidth/2-4
    local talentsEnd=middle+middleWidth/2+3
    D.uiFooterRegion(v,"users",3,usersEnd-3)
    D.uiFooterRegion(v,"talents",usersEnd,talentsEnd-usersEnd)
    D.uiFooterRegion(v,"summary",talentsEnd,w-25-talentsEnd)
    f:SetWidth(w)
    f.users:ClearAllPoints(); f.users:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",6,2)
    f.users:SetWidth(math.max(1,middle-middleWidth/2-14))
    f.talents:ClearAllPoints(); f.talents:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",middle-middleWidth/2,2)
    f.talents:SetWidth(middleWidth)
    fit(f.users,(compact and "C " or "Caw ")..counts[1].."/"..counts[2])
    fit(f.talents,(compact and "T " or "Talents ")..counts[3].."/"..counts[4])
    v.summary:SetWidth(math.max(1,w-27-rightStart)); v.summary:SetJustifyH("RIGHT")
    return true
end
function D.localSyncFooterTooltip(v,tt,role)
    if not v or v.id~=1 then return end
    local known,total,data,remote,members=D.localSyncCounts()
    if role=="users" then
        tt:SetText("Caw users: "..known.."/"..total,1,1,1)
        tt:AddLine("Includes you and group members who replied to Caw.",0.8,0.8,0.8)
        tt:AddLine("No response does not necessarily mean Caw is not installed.",0.8,0.8,0.8)
        for _,m in ipairs(members) do
            tt:AddDoubleLine(m.name,m.detected and "Caw detected" or "No response",1,1,1,0.8,0.8,0.8)
        end
    elseif role=="talents" then
        tt:SetText("Talents synced: "..data.."/"..remote,1,1,1)
        tt:AddLine("Talent profiles received from other group members.",0.8,0.8,0.8)
        tt:AddLine("Your own talents are read locally and are not included.",0.8,0.8,0.8)
        for _,m in ipairs(members) do
            tt:AddDoubleLine(m.name,m.available and "Talent data available" or "Not received",1,1,1,0.8,0.8,0.8)
        end
    end
end
function D.localSyncStatusUpdate()
    D.localSyncFooterCounts={D.localSyncCounts()}
    if D.mainView then D.uiLayoutMeterFooter(D.mainView) end
end

local ticker=CreateFrame("Frame",nil,UIParent)
ticker:SetScript("OnUpdate",function()
    if not D.savedVariablesReady or GetTime()<(D.localSyncNext or 0) then return end
    D.localSyncNext=GetTime()+1
    D.localSyncStatusUpdate()
end)
