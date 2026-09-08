-- Shared single-row header for main and additional windows.
local D=CAW_DPS_METER
function D.layoutSegmentMenu(v)
    local menu=v.segmentMenu
    if not menu then return end
    local width=v.segmentButton:GetWidth()
    menu:SetWidth(width)
    local scroll=menu.up and (not menu.up.IsEnabled or menu.up:IsEnabled() or menu.down:IsEnabled())
    local top=scroll and 20 or 4; local height=0
    for i,b in ipairs(menu.buttons or {}) do
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",menu,"TOPLEFT",4,-top-height)
        b:SetWidth(math.max(1,width-8))
        if b:IsShown() then height=height+b:GetHeight() end
        b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"LEFT",4,0)
        b.text:SetWidth(math.max(1,b:GetWidth()-8)); b.text:SetHeight(16)
        b.text:SetJustifyH("LEFT"); b.text:SetFont(D.uiFont or "Fonts\\FRIZQT__.TTF",12)
    end
    menu:SetHeight(top+height+(scroll and 18 or 4))
    if menu.up then
        menu.up:SetWidth(math.max(1,width-8)); menu.up:SetHeight(13); menu.up:ClearAllPoints(); menu.up:SetPoint("TOPLEFT",menu,"TOPLEFT",4,-3)
        menu.down:SetWidth(math.max(1,width-8)); menu.down:SetHeight(13); menu.down:ClearAllPoints(); menu.down:SetPoint("BOTTOMLEFT",menu,"BOTTOMLEFT",4,3)
        if scroll then menu.up:Show(); menu.down:Show() else menu.up:Hide(); menu.down:Hide() end
    end
    if D.uiStyleMeterMenu then D.uiStyleMeterMenu(v,menu,"segment") end
end
function D.layoutMeterHeader(v)
    local f=v.frame; local w=f:GetWidth() or 440
    local font=D.uiFont or "Fonts\\FRIZQT__.TTF"
    local size=17; local gap=3
    local options=D.uiEnsureOptionsButton and D.uiEnsureOptionsButton(v)
    local overflow=D.uiEnsureOverflowButton and D.uiEnsureOverflowButton(v)
    local compact=overflow and w<300
    if v.headerCompact~=nil and v.headerCompact~=compact and D.uiCloseMeterMenus then D.uiCloseMeterMenus(v) end
    v.headerCompact=compact
    local buttons={}
    local canAdd=false
    if D.multiWindows then for i=2,D.multiWindowMax do if not D.multiWindows[i] then canAdd=true; break end end end
    for _,b in ipairs({v.closeButton,v.lockButton,options,v.resetButton,v.reportButton,v.addButton}) do
        if not compact and (b~=v.addButton or canAdd) then b:Show(); table.insert(buttons,b) else b:Hide() end
    end
    if overflow then if compact then overflow:Show(); table.insert(buttons,overflow) else overflow:Hide() end end
    local i,previous
    for i=1,table.getn(buttons) do
        local b=buttons[i]
        b:ClearAllPoints(); b:SetWidth(size); b:SetHeight(size)
        if previous then b:SetPoint("RIGHT",previous,"LEFT",-gap,0)
        else b:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-(24-size)/2) end
        previous=b
    end
    local reserved=table.getn(buttons)*size+(table.getn(buttons)-1)*gap
    local available=w-14-reserved-5
    -- Give encounter names most of the space; mode labels need a bounded width.
    -- Preserve readable short mode labels in the smallest windows.
    local mw=math.min(110,math.floor((available-3)*0.40))
    local sw=available-3-mw
    if v.modeMenu then
        v.modeMenu:SetWidth(mw)
        for _,b in ipairs(v.modeMenu.buttons or {}) do
            b:SetWidth(math.max(1,mw-8))
            if b.text then
                b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"LEFT",3,0)
                b.text:SetWidth(math.max(1,mw-14)); b.text:SetHeight(16)
                b.text:SetJustifyH("LEFT"); b.text:SetFont(font,12)
            end
        end
        if v.modeMenu.up then v.modeMenu.up:SetWidth(math.max(1,mw-8)) end
        if v.modeMenu.down then v.modeMenu.down:SetWidth(math.max(1,mw-8)) end
    end
    v.modeButton:ClearAllPoints(); v.modeButton:SetWidth(mw); v.modeButton:SetHeight(18)
    v.modeButton:SetPoint("TOPLEFT",f,"TOPLEFT",5,-3)
    v.segmentButton:ClearAllPoints(); v.segmentButton:SetWidth(sw); v.segmentButton:SetHeight(18)
    v.segmentButton:SetPoint("LEFT",v.modeButton,"RIGHT",3,0)
    D.layoutSegmentMenu(v)
    local selectors={{v.modeButton,v.modeText,v.modeArrow,mw},{v.segmentButton,v.segmentText,v.segmentArrow,sw}}
    for i=1,2 do
        local s=selectors[i]; local arrow=s[3]; local inset=w<200 and 3 or 5
        s[2]:ClearAllPoints(); s[2]:SetPoint("LEFT",s[1],"LEFT",inset,0)
        s[2]:SetWidth(math.max(8,s[4]-inset-12))
        s[2]:SetHeight(14); s[2]:SetFont(font,11)
        if arrow then
            arrow:ClearAllPoints(); arrow:SetPoint("RIGHT",s[1],"RIGHT",-4,0)
            arrow:Show()
        end
    end
    if v.reportMenu then
        v.reportMenu:ClearAllPoints(); v.reportMenu:SetPoint("TOPRIGHT",compact and overflow or v.reportButton,"BOTTOMRIGHT",0,-2)
    end
    v.header:SetHeight(23)
    v.headerLine:ClearAllPoints(); v.headerLine:SetPoint("TOPLEFT",f,"TOPLEFT",1,-24); v.headerLine:SetPoint("TOPRIGHT",f,"TOPRIGHT",-1,-24)
    v.toolbar:Hide(); v.toolbarLine:Hide()
    v.summary:ClearAllPoints(); v.summary:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",6,3)
    v.summary:SetWidth(math.max(1,w-26)); v.summary:SetHeight(12); v.summary:SetJustifyH("LEFT"); v.summary:SetFont(font,9); v.summary:Show()
    v.brand:ClearAllPoints(); v.brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawBrand.tga")
    local bw=math.min(230,w-24); v.brand:SetWidth(bw); v.brand:SetHeight(bw/8)
    -- Window artwork sits above the backdrop but behind child player bars.
    -- A texture cannot receive mouse input. Keep it present with populated lists.
    v.brand:SetPoint("CENTER",f,"CENTER",0,-4); v.brand:SetAlpha(0.40); v.brand:Show()
end
