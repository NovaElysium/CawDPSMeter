-- Shared single-row header for main and additional windows.
local D=CAW_DPS_METER
function D.layoutMeterHeader(v)
    local f=v.frame; local w=f:GetWidth() or 440
    local small=w<260; local size=small and 13 or 17; local gap=small and 2 or 3
    local buttons={v.closeButton,v.resetButton,v.lockButton,v.reportButton,v.addButton}
    local i,previous
    for i=1,table.getn(buttons) do
        local b=buttons[i]
        b:ClearAllPoints(); b:SetWidth(size); b:SetHeight(size)
        if previous then b:SetPoint("RIGHT",previous,"LEFT",-gap,0)
        else b:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-(24-size)/2) end
        previous=b
    end
    local reserved=5*size+4*gap
    local available=w-14-reserved-5
    -- Give encounter names most of the space; mode labels need a bounded width.
    -- Preserve readable short mode labels in the smallest windows.
    local mw=math.min(110,math.floor((available-3)*(small and 0.60 or 0.40)))
    local sw=available-3-mw
    if v.modeMenu then
        v.modeMenu:SetWidth(mw)
        for _,b in ipairs(v.modeMenu.buttons or {}) do
            b:SetWidth(math.max(1,mw-8))
            if b.text then
                b.text:ClearAllPoints(); b.text:SetPoint("LEFT",b,"LEFT",3,0)
                b.text:SetWidth(math.max(1,mw-14)); b.text:SetHeight(12)
                b.text:SetJustifyH("LEFT"); b.text:SetFont("Fonts\\FRIZQT__.TTF",9)
            end
        end
        if v.modeMenu.up then v.modeMenu.up:SetWidth(math.max(1,mw-8)) end
        if v.modeMenu.down then v.modeMenu.down:SetWidth(math.max(1,mw-8)) end
    end
    v.modeButton:ClearAllPoints(); v.modeButton:SetWidth(mw); v.modeButton:SetHeight(18)
    v.modeButton:SetPoint("TOPLEFT",f,"TOPLEFT",5,-3)
    v.segmentButton:ClearAllPoints(); v.segmentButton:SetWidth(sw); v.segmentButton:SetHeight(18)
    v.segmentButton:SetPoint("LEFT",v.modeButton,"RIGHT",3,0)
    local selectors={{v.modeButton,v.modeText,v.modeArrow,mw},{v.segmentButton,v.segmentText,v.segmentArrow,sw}}
    for i=1,2 do
        local s=selectors[i]; local arrow=s[3]; local inset=w<200 and 3 or 5
        s[2]:ClearAllPoints(); s[2]:SetPoint("LEFT",s[1],"LEFT",inset,0)
        s[2]:SetWidth(math.max(8,s[4]-inset-(w<200 and 3 or 14)))
        s[2]:SetHeight(12); s[2]:SetFont("Fonts\\FRIZQT__.TTF",small and 9 or 11)
        if arrow then
            arrow:ClearAllPoints(); arrow:SetPoint("RIGHT",s[1],"RIGHT",-4,0)
            if w<200 then arrow:Hide() else arrow:Show() end
        end
    end
    v.header:SetHeight(23)
    v.headerLine:ClearAllPoints(); v.headerLine:SetPoint("TOPLEFT",f,"TOPLEFT",1,-24); v.headerLine:SetPoint("TOPRIGHT",f,"TOPRIGHT",-1,-24)
    v.toolbar:Hide(); v.toolbarLine:Hide()
    v.summary:ClearAllPoints(); v.summary:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",6,3)
    v.summary:SetWidth(math.max(1,w-26)); v.summary:SetHeight(12); v.summary:SetJustifyH("LEFT"); v.summary:SetFont("Fonts\\FRIZQT__.TTF",9); v.summary:Show()
    v.brand:ClearAllPoints(); v.brand:SetTexture("Interface\\AddOns\\CawDPSMeter\\Media\\CawBrand.tga")
    local bw=math.min(230,w-24); v.brand:SetWidth(bw); v.brand:SetHeight(bw/8)
    -- Window artwork sits above the backdrop but behind child player bars.
    -- A texture cannot receive mouse input. Keep it present with populated lists.
    v.brand:SetPoint("CENTER",f,"CENTER",0,-4); v.brand:SetAlpha(0.40); v.brand:Show()
end
