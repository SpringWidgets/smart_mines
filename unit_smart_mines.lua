function widget:GetInfo()
    return {
        name      = "Smart Mines", -- and self-d when enemy is near v1
        desc      = "Mines are set on HoldFire",-- and self-d when enemy is near
        author    = "[teh]decay",
        date      = "14 feb 2015",
        license   = "The BSD License",
        layer     = 0,
        version   = 2,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/SpringWidgets/smart_mines

-- Changelog
-- v2 Floris Added crawling bombs, Added fade on camera distance changed to thicker and more transparant line style + options + onlyDrawRangeWhenSelected

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

local onlyDrawRangeWhenSelected	= true
local fadeOnCameraDistance		= true
local showLineGlow 				= true		-- a ticker but faint 2nd line will be drawn underneath	
local opacityMultiplier			= 1.15
local fadeMultiplier			= 0.8		-- lower value: fades out sooner
local circleDivs				= 64		-- detail of range circle

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetUnitPosition     	= Spring.GetUnitPosition
local glColor				= gl.Color
local glLineWidth 			= gl.LineWidth
local glDepthTest			= gl.DepthTest
local glDrawGroundCircle	= gl.DrawGroundCircle
local GetUnitDefID			= Spring.GetUnitDefID
local lower                 = string.lower
local spGetAllUnits			= Spring.GetAllUnits
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spGetCameraPosition 	= Spring.GetCameraPosition
local spValidUnitID			= Spring.ValidUnitID
local spGetUnitPosition		= Spring.GetUnitPosition
local spIsSphereInView		= Spring.IsSphereInView
local spIsUnitSelected		= Spring.IsUnitSelected
local spIsGUIHidden			= Spring.IsGUIHidden

local cmdFireState 			= CMD.FIRE_STATE

local weapNamTab			= WeaponDefNames
local weapTab				= WeaponDefs
local udefTab				= UnitDefs

local selfdTag = "selfDExplosion"
local aoeTag = "damageAreaOfEffect"

local armmine1 = UnitDefNames["armmine1"]
local armmine2 = UnitDefNames["armmine2"]
local armmine3 = UnitDefNames["armmine3"]
local armfmine3 = UnitDefNames["armfmine3"]  -- floating


local cormine1 = UnitDefNames["cormine1"]
local cormine2 = UnitDefNames["cormine2"]
local cormine3 = UnitDefNames["cormine3"]
local cormine4 = UnitDefNames["cormine4"]
local corfmine3 = UnitDefNames["corfmine3"]  -- floating

--crawling bombs
local armvader = UnitDefNames["armvader"]
local corroach = UnitDefNames["corroach"]
local corsktl = UnitDefNames["corsktl"]


local holdfireUnits = {}		-- commando mines exluded
holdfireUnits[armmine1.id] = true
holdfireUnits[armmine2.id] = true
holdfireUnits[armmine3.id] = true
holdfireUnits[armfmine3.id] = true
holdfireUnits[cormine1.id] = true
holdfireUnits[cormine2.id] = true
holdfireUnits[cormine3.id] = true
holdfireUnits[corfmine3.id] = true


local mineIds = {}
mineIds[armmine1.id] = armmine1
mineIds[armmine2.id] = armmine2
mineIds[armmine3.id] = armmine3
mineIds[armfmine3.id] = armfmine3

mineIds[cormine1.id] = cormine1
mineIds[cormine2.id] = cormine2
mineIds[cormine3.id] = cormine3
mineIds[cormine4.id] = cormine4
mineIds[corfmine3.id] = corfmine3

mineIds[armvader.id] = armvader
mineIds[corroach.id] = corroach
mineIds[corsktl.id] = corsktl

local allMines = {}

local spectatorMode = false
local notInSpecfullmode = false

function setMineOnHoldFire(unitID)
    spGiveOrderToUnit(unitID, cmdFireState, { 0 }, {  })
end

function isMine(unitDefID)
    return mineIds[unitDefID] ~= nil
end

function addMine(unitID, unitDefID)
	
	local udef = udefTab[unitDefID]
	local selfdBlastId = weapNamTab[lower(udef[selfdTag])].id
	local selfdBlastRadius = weapTab[selfdBlastId][aoeTag]
	allMines[unitID] = {selfdBlastRadius}
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if isMine(unitDefID) then
		addMine(unitID, unitDefID)
		if holdfireUnits[unitDefID] ~= nil then
			setMineOnHoldFire(unitID)
		end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if allMines[unitID] then
        allMines[unitID] = nil
    end
end

function widget:UnitEnteredLos(unitID, unitTeam)
    if not spectatorMode then
        local unitDefID = GetUnitDefID(unitID)
        if isMine(unitDefID) then
			addMine(unitID, unitDefID)
        end
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not spValidUnitID(unitID) then return end --because units can be created AND destroyed on the same frame, in which case luaui thinks they are destroyed before they are created
	
    if isMine(unitDefID) then
		addMine(unitID, unitDefID)
		if holdfireUnits[unitDefID] ~= nil then
			setMineOnHoldFire(unitID)
		end
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if isMine(unitDefID) then
		addMine(unitID, unitDefID)
		if holdfireUnits[unitDefID] ~= nil then
			setMineOnHoldFire(unitID)
		end
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if isMine(unitDefID) then
		addMine(unitID, unitDefID)
		if holdfireUnits[unitDefID] ~= nil then
			setMineOnHoldFire(unitID)
		end
    end
end

function widget:UnitLeftLos(unitID, unitDefID, unitTeam)
    if not spectatorMode then
        if allMines[unitID] then
            allMines[unitID] = nil
        end
    end
end

function widget:DrawWorldPreUnit()
    local _, specFullView, _ = spGetSpectatingState()

    if not specFullView then
        notInSpecfullmode = true
    else
        if notInSpecfullmode then
            detectSpectatorView()
        end
        notInSpecfullmode = false
    end
	
    if spIsGUIHidden() then return end
    
	local camX, camY, camZ = spGetCameraPosition()
	
    glDepthTest(true)

    for unitID,property in pairs(allMines) do
        local x,y,z = GetUnitPosition(unitID)
		if ((onlyDrawRangeWhenSelected and spIsUnitSelected(unitID)) or onlyDrawRangeWhenSelected == false) and spIsSphereInView(x,y,z,property[1]) then
			local xDifference = camX - x
			local yDifference = camY - y
			local zDifference = camZ - z
			local camDistance = math.sqrt(xDifference*xDifference + yDifference*yDifference + zDifference*zDifference)
			
			local lineWidthMinus = (camDistance/2000)
			if lineWidthMinus > 2 then
				lineWidthMinus = 2
			end
			local lineOpacityMultiplier = 0.85
			if fadeOnCameraDistance then
				lineOpacityMultiplier = (1100/camDistance)*fadeMultiplier
				if lineOpacityMultiplier > 1 then
					lineOpacityMultiplier = 1
				end
			end
			if lineOpacityMultiplier > 0.15 then
				
				if showLineGlow then
					glLineWidth(10)
					glColor(1, 0, 0.5,  .03*lineOpacityMultiplier*opacityMultiplier)
					glDrawGroundCircle(x, y, z, property[1], circleDivs)
				end
				glLineWidth(2.2-lineWidthMinus)
				glColor(1, 0, 0.5,  .44*lineOpacityMultiplier*opacityMultiplier)
				glDrawGroundCircle(x, y, z, property[1], circleDivs)
			end
		end
	end
    glDepthTest(false)
end

function widget:PlayerChanged(playerID)
    detectSpectatorView()
    return true
end

function widget:Initialize()
    detectSpectatorView()
    return true
end

function detectSpectatorView()
    local _, _, spec, teamId = spGetPlayerInfo(spGetMyPlayerID())

    if spec then
        spectatorMode = true
    end

    local visibleUnits = spGetAllUnits()
    if visibleUnits ~= nil then
        for _, unitID in ipairs(visibleUnits) do
            local unitDefID = GetUnitDefID(unitID)
            if unitDefID ~= nil then
                if isMine(unitDefID) then
					addMine(unitID, unitDefID)
                end
            end
        end
    end
end
