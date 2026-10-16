local D=CAW_DPS_METER
local checks=0
local function check(ok,label) assert(ok,label); checks=checks+1; print("PASS SELF BAR "..label) end
local function actor(key,name,amount,pet)
    return {key=key,guid=key,name=name,classToken=not pet and "HUNTER" or nil,isPet=pet,
        damage=amount,healing=0,spells={Shot={damage=amount,hits=1,crits=0}},healSpells={}}
end
-- Twelve players ranked by damage. The mocked local player is "0x1" / "Hunter".
local function build(selfRank)
    local actors={}; local i
    for i=1,12 do
        local key="0xB"..string.format("%02d",i); local name="Player"..i
        if i==selfRank then key="0x1"; name="Hunter" end
        actors[key]=actor(key,name,(13-i)*100)
    end
    return actors
end
local savedActors,savedSegment,savedMode=D.actors,D.segment,D.mode
D.segment="current"; D.segmentIndex=0; D.mode="damage"
D.appearance=D.uiCopySettings(nil)
D.window:Show()
D.window:SetWidth(360); D.window:SetHeight(D.uiHeightForRows(nil,5)); D.applyCompactWindowLayout()
local v=D.multiWindows[2] or D.createMultiWindow(nil)
v.appearance=D.uiCopySettings(nil); v.frame:Show(); v.mode="damage"; v.segment="current"
v.frame:SetHeight(D.uiHeightForRows(v,5)); D.layoutMultiWindow(v)
check(D.uiSettings().alwaysShowMe==false and D.uiSettings(v).alwaysShowMe==false,"option is off by default for every window")
check(D.uiVisibleRows(nil,D.window)==5 and D.uiVisibleRows(v,v.frame)==5,"test windows show five bars")

local function paint(win)
    if win==D.window then D.uiRefreshMeters() else D.updateMultiWindow(v) end
end
-- Returns {name,...} and {rank text,...} of the painted rows.
local function shown(win)
    local rows=(win==D.window) and D.rows or v.rows; local names,ranks={},{}
    local i
    for i=1,5 do
        local r=rows[i]
        if r.actor then table.insert(names,r.actor.name); table.insert(ranks,r.rank:GetText()) end
    end
    return names,ranks
end
local function offsetOf(win,o) if win==D.window then D.scrollOffset=o else v.scrollOffset=o end end
local function count(list,name) local n=0; for _,x in ipairs(list) do if x==name then n=n+1 end end; return n end

for _,win in ipairs({D.window,v}) do
    local label=(win==D.window) and "main window" or "extra window"
    local settings=(win==D.window) and D.uiSettings() or D.uiSettings(v)
    D.actors=build(9); settings.alwaysShowMe=false
    offsetOf(win,0); paint(win)
    local names=shown(win)
    check(names[1]=="Player1" and names[5]=="Player5" and count(names,"Hunter")==0,label.." leaves a scrolled-out own bar hidden by default")
    settings.alwaysShowMe=true; offsetOf(win,0); paint(win)
    local names,ranks=shown(win)
    check(names[5]=="Hunter" and ranks[5]=="9." and names[4]=="Player4" and ranks[1]=="1.",label.." pins the own bar to the last row with its real rank")
    offsetOf(win,6); paint(win)
    names,ranks=shown(win)
    check(names[1]=="Player7" and names[3]=="Hunter" and count(names,"Hunter")==1 and names[5]=="Player11",label.." keeps a visible own bar in its natural place")
    -- Every player stays reachable and the own bar never appears twice.
    local seen={}; local o; local worst=0
    for o=0,12 do
        offsetOf(win,o); paint(win)
        names=shown(win)
        local n=count(names,"Hunter"); if n>worst then worst=n end
        for _,x in ipairs(names) do seen[x]=true end
    end
    local all=0; for _ in pairs(seen) do all=all+1 end
    check(worst==1 and all==12,label.." shows the own bar exactly once and still reaches all twelve players")
    -- A top-ranked player is pinned while scrolling down, and the last player stays reachable.
    D.actors=build(2); offsetOf(win,0); paint(win)
    names,ranks=shown(win)
    check(names[2]=="Hunter" and count(names,"Hunter")==1,label.." keeps a top-ranked own bar in place")
    offsetOf(win,99); paint(win)
    names,ranks=shown(win)
    check(names[5]=="Hunter" and ranks[5]=="2." and names[4]=="Player12",label.." can scroll to the last player while the own bar stays pinned")
    -- A short list needs no pinning and the toggle restores the plain list.
    D.actors={}; D.actors["0x1"]=actor("0x1","Hunter",50); D.actors["0xB01"]=actor("0xB01","Player1",90)
    offsetOf(win,0); paint(win)
    names=shown(win)
    check(table.getn(names)==2 and names[1]=="Player1" and names[2]=="Hunter",label.." changes nothing when everything fits")
    -- Pets and same-named actors that are not the player are never pinned.
    local pets=build(12); pets["0x1"]=nil; pets["0xB12"]=actor("0xP12","Hunter",1,true)
    D.actors=pets; offsetOf(win,0); paint(win)
    names=shown(win)
    check(count(names,"Hunter")==0,label.." never pins a pet that shares the player's name")
    D.actors=build(9); settings.alwaysShowMe=false; offsetOf(win,0); paint(win)
    names=shown(win)
    check(count(names,"Hunter")==0 and names[5]=="Player5",label.." turning the option off restores the plain list")
end

-- The periodic timer must repaint after the option changes, even without new combat data.
D.actors=build(9); D.scrollOffset=0; D.uiSettings().alwaysShowMe=false; D.uiRefreshMeters()
D.uiSettings().alwaysShowMe=true
local prev=this; this=D.window; D.window.nextUpdate=0; D.window.scripts.OnUpdate(); this=prev
local names=shown(D.window)
check(names[5]=="Hunter","timer repaint picks up a changed option without a data change")
D.uiSettings().alwaysShowMe=false; D.uiSettings(v).alwaysShowMe=false
-- The option survives settings copies and saved appearance.
local copy=D.uiCopySettings({alwaysShowMe=true})
check(copy.alwaysShowMe==true and D.uiCopySettings(nil).alwaysShowMe==false and D.uiCopySettings({alwaysShowMe="yes"}).alwaysShowMe==false,"option is saved as a boolean and defaults to off")
D.actors=savedActors; D.segment=savedSegment; D.mode=savedMode
D.uiRefreshMeters()
print("Always show me checks: "..checks)
