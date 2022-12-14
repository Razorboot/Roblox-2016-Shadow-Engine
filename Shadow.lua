--[[
	Built off of: https://scriptinghelpers.org/guides/silhouettes-and-shadows
	Created By: Razorboot
	Last Modified: 12/3/22
	Description: 
		- An attempt at an optimized raycasted shadow-polygon implementation. 
		- This is a complex set of object oriented mini-classes and polygonal algorithms for:
			- accurate n-gon to triangle conversion,
			- clipped polygons,
			- multiple light sources,
			- optimized vertex grabbing,
			- ray to plane intersection,
			- rotated shadow occluders and canvases,
			- world position shadows to 2d space, clipped, triangle-based shadows,
			- surface-based real-time lighting calculations:
				- an attempt to make the system appear more well-integrated with shadow engine.
		- Inspired by early 2000's Shadow Volumes in games like Thief: Deadly Shadows and Doom III.
		- Manifold data-structure system was inspired by collision manifolds in AABB physics.
			- This implementation is classless and includes nested arrays as a form of orginization.
	
	New Changes:
		- I can confidently say that, in the realm of cube-shapes parts, the current engine is complete!
		- Complex multi-surface shadows supported.
		- Rotated parts (occluders and canvases) now supported.
		- A mini lighting engine for rendering part surfaces is now added and functional in real-time!
			- This supports multiple lighting options you now have control over in Shadow script!
		- Shadows are now Surface-Gui based for more optimal results.
		- Global Lighting is now supported! Local lighting can also be disabled/enabled in module settings.
--]]


--# Services
local Lighting = game:GetService("Lighting")


--# Include
local Modules = script.Parent
local BaseFuncs = require(Modules:WaitForChild("BaseFuncs")) -- My own library with a collection of modern functions supported for old Roblox.
local Poly = require(script:WaitForChild("Polygon")) -- My own polygon library for clipping polygons :]
local Hull = require(script:WaitForChild("GiftWrapHull")) -- Used to order polygon vertices
local Tris = require(script:WaitForChild("Triangle")) -- Used to create Instances of polygons as ImageLabels
local Deluany = require(script:WaitForChild("Deluany")) -- Used to create Instances of polygons as ImageLabels


--# Math references (optimization)
local vec3 = Vector3.new
local vec2 = Vector2.new
local cf = CFrame.new
local cfa = CFrame.Angles
local udim2 = UDim2.new
local c3 = Color3.new


--# Instance References
local hasShadowColorInstance = script:WaitForChild("hasShadowColor")
local hasAmbientInstance = script:WaitForChild("hasAmbient")
local hasShadowBrightnessInstance = script:WaitForChild("hasShadowBrightness")
local hasGlobalShadowBrightnessInstance = script:WaitForChild("hasGlobalShadowBrightness")
local hasGlobalLightingInstance = script:WaitForChild("hasGlobalLighting")
local hasLocalLightingInstance = script:WaitForChild("hasLocalLighting")
local useLightingPropertiesInstance = script:WaitForChild("useLightingProperties")
local useExperimentalInstance = script:WaitForChild("useExperimental")


--# Point
local Shadow = {}


--# Storage components - helps code run faster (less GetDescendants)
Shadow.AllLightSources = {}


--# Misc Variables
local transparency = 0.5
local ambient = 0.25
local useLightingProperties = useLightingPropertiesInstance.Value
local shadowColor = hasShadowColorInstance.Value
local shadowColorIsMemberOfLighting = BaseFuncs.hasProperty(Lighting, "ShadowColor")
local globalLightingEnabled = hasGlobalLightingInstance.Value
local localLightingEnabled = hasLocalLightingInstance.Value

local prevSunDir = Lighting:GetSunDirection()
local sunUpdateNeeded = false
local localUpdateNeeded = false
	
	
--# Local Functions
local function updateLighting()
	useLightingProperties = useLightingPropertiesInstance.Value
	
	if hasAmbientInstance.Value >= 0 then ambient = hasAmbientInstance.Value end
	if hasShadowBrightnessInstance.Value >= 0 then transparency = hasShadowBrightnessInstance.Value end
	shadowColor = hasShadowColorInstance.Value
	
	if Lighting:GetSunDirection() ~= prevSunDir then
		sunUpdateNeeded = true
	else
		sunUpdateNeeded = false
	end
	
	if globalLightingEnabled ~= hasGlobalLightingInstance.Value then
		globalLightingEnabled = hasGlobalLightingInstance.Value
		sunUpdateNeeded = true
	end
	
	if hasLocalLightingInstance.Value ~= localLightingEnabled then
		localLightingEnabled = hasLocalLightingInstance.Value
		localUpdateNeeded = true
	else
		localUpdateNeeded = false
	end

	if useLightingProperties == true then
		ambient = vec3(Lighting.Ambient.r, Lighting.Ambient.g, Lighting.Ambient.b) + vec3(Lighting.OutdoorAmbient.r, Lighting.OutdoorAmbient.g, Lighting.OutdoorAmbient.b)
		transparency = math.min(math.min(Lighting.Brightness, 5), 1)
		if globalLightingEnabled ~= Lighting.GlobalShadows then
			globalLightingEnabled = Lighting.GlobalShadows
			sunUpdateNeeded = true
		end
		globalLightingEnabled = Lighting.GlobalShadows
		if shadowColorIsMemberOfLighting then
			shadowColor = Lighting.ShadowColor
		end
	end
end

updateLighting()

 
-- Vertex Information for unique cases
local sphereVertices = {}
table.insert(sphereVertices, {-0.35355335474014, 0.35355335474014, 0} )
table.insert(sphereVertices, {-0.24999997019768, 0.35355335474014, 0.24999997019768} )
table.insert(sphereVertices, {0, 0.35355335474014, 0.35355335474014} )
table.insert(sphereVertices, {-0.35355338454247, 0, -0.35355338454247} )
table.insert(sphereVertices, {0, 0.49999997019768, 0} )
table.insert(sphereVertices, {-0.24999997019768, 0.35355335474014, -0.24999997019768} )
table.insert(sphereVertices, {0.24999997019768, 0.35355335474014, 0.24999997019768} )
table.insert(sphereVertices, {-0.5, 0, 0} )
table.insert(sphereVertices, {0, -0.35355335474014, 0.35355335474014} )
table.insert(sphereVertices, {0.24999997019768, -0.35355335474014, -0.24999997019768} )
table.insert(sphereVertices, {0, -0.49999997019768, 0} )
table.insert(sphereVertices, {-0.24999997019768, -0.35355335474014, 0.24999997019768} )
table.insert(sphereVertices, {0, 0, -0.5} )
table.insert(sphereVertices, {0.35355338454247, 0, -0.35355338454247} )
table.insert(sphereVertices, {-0.35355338454247, 0, 0.35355338454247} )
table.insert(sphereVertices, {0.24999997019768, 0.35355335474014, -0.24999997019768} )
table.insert(sphereVertices, {0, -0.35355335474014, -0.35355335474014} )
table.insert(sphereVertices, {0, 0, 0.5} )
table.insert(sphereVertices, {0, 0.35355335474014, -0.35355335474014} )
table.insert(sphereVertices, {-0.24999997019768, -0.35355335474014, -0.24999997019768} )
table.insert(sphereVertices, {0.5, 0, 0} )
table.insert(sphereVertices, {0.35355338454247, 0, 0.35355338454247} )
table.insert(sphereVertices, {0.24999997019768, -0.35355335474014, 0.24999997019768} )
table.insert(sphereVertices, {0.35355335474014, -0.35355335474014, 0} )
table.insert(sphereVertices, {0.35355335474014, 0.35355335474014, 0} )
table.insert(sphereVertices, {-0.35355335474014, -0.35355335474014, 0} )


--[[----------------------------------------------------------------------------------------------------
	FUNCTIONS
--]]----------------------------------------------------------------------------------------------------


--# Edge Calculations
local lefts = {
	[Enum.NormalId.Top] = Vector3.FromNormalId(Enum.NormalId.Left);
	[Enum.NormalId.Back] = Vector3.FromNormalId(Enum.NormalId.Left);
	[Enum.NormalId.Right] = Vector3.FromNormalId(Enum.NormalId.Back);
	[Enum.NormalId.Bottom] = Vector3.FromNormalId(Enum.NormalId.Right);
	[Enum.NormalId.Front] = Vector3.FromNormalId(Enum.NormalId.Right);
	[Enum.NormalId.Left] = Vector3.FromNormalId(Enum.NormalId.Front);
};	

function getEdges(part)
    local connects = {}

    -- get the corners
    local size, corners = part.Size / 2, {}
    for x = -1, 1, 2 do
        for y = -1, 1, 2 do
            for z = -1, 1, 2 do
                table.insert(corners, (part.CFrame * cf(size * vec3(x, y, z))).p)
            end
        end
    end

    -- get each corner and the surface normals connected to it
    connects[1] = {}
    connects[1].corner = corners[1]
    table.insert(connects[1], {corners[1], corners[2]})
    table.insert(connects[1], {corners[1], corners[3]})
    table.insert(connects[1], {corners[1], corners[5]})

    connects[2] = {}
    connects[2].corner = corners[2]
    table.insert(connects[2], {corners[2], corners[1]})
    table.insert(connects[2], {corners[2], corners[4]})
    table.insert(connects[2], {corners[2], corners[6]})

    connects[3] = {}
    connects[3].corner = corners[3]
    table.insert(connects[3], {corners[3], corners[1]})
    table.insert(connects[3], {corners[3], corners[4]})
    table.insert(connects[3], {corners[3], corners[7]})    

    connects[4] = {}
    connects[4].corner = corners[4]
    table.insert(connects[4], {corners[4], corners[2]})
    table.insert(connects[4], {corners[4], corners[3]})
    table.insert(connects[4], {corners[4], corners[8]})

    connects[5] = {}
    connects[5].corner = corners[5]
    table.insert(connects[5], {corners[5], corners[1]})
    table.insert(connects[5], {corners[5], corners[6]})
    table.insert(connects[5], {corners[5], corners[7]})    

    connects[6] = {}
    connects[6].corner = corners[6]
    table.insert(connects[6], {corners[6], corners[8]})
    table.insert(connects[6], {corners[6], corners[5]})
    table.insert(connects[6], {corners[6], corners[2]})

    connects[7] = {}
    connects[7].corner = corners[7]
    table.insert(connects[7], {corners[7], corners[8]})
    table.insert(connects[7], {corners[7], corners[5]})
    table.insert(connects[7], {corners[7], corners[3]})

    connects[8] = {}
    connects[8].corner = corners[8]
    table.insert(connects[8], {corners[8], corners[7]})
    table.insert(connects[8], {corners[8], corners[6]})
    table.insert(connects[8], {corners[8], corners[4]})

    -- calculate the normal vectos
    for i, set in ipairs(connects) do
        for _, corners in ipairs(set) do
            corners.vector = (corners[1] - corners[2]).unit
        end
    end

    return connects
end

function getCorners(part, sourcePos, isGlobal)
    local lcorners = {}
    for k, set in next, getEdges(part) do
        local passCount = 0
        -- same calculation as the 2D one
		for i = 1, 3 do
			local lightVector
			if isGlobal == true then
				lightVector = sourcePos
			else
				lightVector = (sourcePos - set.corner).unit
			end
			
            local dot = set[i].vector:Dot(lightVector)
            if dot >= 0 then
                passCount = passCount + 1
            end
        end
        -- light can't shine on all 3 or none of the surfaces, must be inbetween
       	if passCount > 0 and passCount < 3 then
            table.insert(lcorners, set.corner)
        end
    end
    return lcorners
end

function getEdgesSphere(part)
	-- get the corners
	local size, corners = part.Size, {}
	
	for i, vertex in pairs(sphereVertices) do
		local newCorner = {}
		local unMarkedPos = vec3(vertex[1], vertex[2], vertex[3])
		newCorner.pos = part.Position + (unMarkedPos * (size))
		newCorner.normal = unMarkedPos.unit
		table.insert(corners, newCorner)
	end
	
	return corners
end

function getCornersSphere(part, sourcePos, isGlobal)
	local lcorners = {}
	
	for _, corner in pairs(getEdgesSphere(part)) do
		local passCount = 0
		
		local lightVector
		if isGlobal == true then
			lightVector = sourcePos
		else
			lightVector = (sourcePos - corner.pos).unit
		end
		
        local dot = corner.normal:Dot(lightVector)
        if dot >= 0 then
            passCount = passCount + 1
        end

		-- light can't shine on all 3 or none of the surfaces, must be inbetween
		if passCount >= 0 then
			table.insert(lcorners, corner.pos)
	   end
	end
	
	return lcorners
end

-- Light Source Functions
local function isLightSourceIsNearby(light, point, offset)
	local lightRange = light:FindFirstChild("hasShadowRange")
	if lightRange then lightRange = lightRange.Value else lightRange = light.Range end
	
	if (light.Parent.Position - point).magnitude < (lightRange + offset) then
		return true
	end
end

function Shadow.insertLightSource(light)
	local rangeInstance = light:FindFirstChild("hasShadowRange")
	local lRange = light.Range
	if rangeInstance then 
		lRange = rangeInstance.Value
	end
	
	table.insert(Shadow.AllLightSources, {
		instance = light,
		part = light.Parent,
		pos = light.Parent.Position,
		range = lRange,
		posChanged = false
	})
end

function Shadow.removeLightSource(instance)
	for i, lightManifold in pairs(Shadow.AllLightSources) do
		if lightManifold.instance == instance then table.remove(Shadow.AllLightSources, i) return end
	end
end

function Shadow.getAllLightSources(location)
	for _, light in pairs(BaseFuncs.GetDescendants(workspace)) do
		if light:IsA("PointLight") or light:IsA("SpotLight") then
			Shadow.insertLightSource(light)
		end
	end
end

function Shadow.updateAllLightSources()
	for i, lightManifold in pairs(Shadow.AllLightSources) do
		-- Remove light source if the instance does no longer exist
		if lightManifold.instance == nil then
			table.remove(Shadow.AllLightSources, i)
		else
			-- Update the position of the light source if it's moved
			if lightManifold.part.Position ~= lightManifold.pos then
				lightManifold.posChanged = true
			else
				lightManifold.posChanged = false
			end
			
			lightManifold.pos = lightManifold.part.Position
		end
	end
end

local function getNearbyLightSources(point, offset)
	local lightSources = {}
	offset = offset or 0
	
	for i, lightManifold in pairs(Shadow.AllLightSources) do
		if (lightManifold.part.Position - point).magnitude < (lightManifold.range + offset) then
			table.insert(lightSources, i)
		end
	end
	
	return lightSources
end


--# Ray to Plane intersection
function planeIntersectClipped(point, vector, origin, normal)
	local rpoint = point - origin;
	local vecDotNorm = vector:Dot(normal)
	local rDotNorm = rpoint:Dot(normal)
	
	local t = -rDotNorm / vecDotNorm;	
	if (rDotNorm / vecDotNorm) <= -0.1 then
		return point + t * vector;
	end
end

--[[function planeIntersect(point, vector, origin, normal, overeach)
	local rpoint = point - origin;
	local vecDotNorm = vector:Dot(normal)
	local rDotNorm = rpoint:Dot(normal)
	
	local t = -rDotNorm / vecDotNorm;	
	
	local hit1 = point + t * vector
	local hit2 = nil
	if overeach == true then
		hit2 = planeIntersectClipped(point + vector * -999999, normal, origin, normal)
	end
	if (rDotNorm / vecDotNorm) <= -0.1 then
		if hit2 == nil then hit1 = nil end
	end
	
	return hit1, hit2;
end;]]

function planeIntersect(point, vector, origin, normal, overeach)
	local rpoint = point - origin;
	local vecDotNorm = vector:Dot(normal)
	local rDotNorm = rpoint:Dot(normal)
	
	local t = -rDotNorm / vecDotNorm;	
	
	local hit1 = point + t * vector
	
	if (rDotNorm / vecDotNorm) <= -0.1 then
		hit1 = nil
	end
	
	return hit1;
end;

function planeProject(point, v, orig, normal)
	local v = point - orig
	local dist = v * normal
	return point - dist * normal
end


--# Implementation Functions
local function newRootManifold(SurfaceGui)
	local part = SurfaceGui.Parent
			
	-- Root canvas manifold
	local canvasManifold = {}
	canvasManifold.part = part
	canvasManifold.partCF = CFrame.new(part.CFrame:components())
	canvasManifold.canvas = SurfaceGui
	
	-- Each occluder has a manifold that contains relevant light sources and the shadows they cast
	canvasManifold.occluderManifolds = {}
	
	-- Where shadow mesh instances are stored
	 --[[canvasManifold.instanceStorage = Instance.new("Model", workspace)
	canvasManifold.instanceStorage.Name = "ShadowStorage_"..part.Name]]
	canvasManifold.instanceStorage = {}
	
	-- Occluder manifolds (nested inside base manifolds)
	for _, occluderPart in pairs(BaseFuncs.GetDescendants(workspace)) do
		if occluderPart:IsA("BasePart") and occluderPart:FindFirstChild("isShadowOccluder") and occluderPart ~= canvasManifold.part then
			-- Create occluder manifold
			local occluderManifold = {}
			occluderManifold.occluder = occluderPart
			occluderManifold.occluderCF = occluderPart.CFrame
			-- Create manifolds for relative lights and corresponding corners
			occluderManifold.shadowManifolds = {}
			local lightSources = getNearbyLightSources(occluderManifold.occluder.Position)
			
			for _, li in pairs(lightSources) do
				local shadowManifold = {}
				shadowManifold.li = li
				shadowManifold.brightness = 1
				if occluderManifold.occluder.Shape == Enum.PartType.Ball then
					shadowManifold.corners = getCornersSphere(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
				else
					shadowManifold.corners = getCorners(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
				end
				shadowManifold.instanceStorage = {}
				
				-- Apply current SM to shadowManifolds
				table.insert(occluderManifold.shadowManifolds, shadowManifold)
			end
			
			-- Global Lighting
			occluderManifold.globalShadowManifold = {}
			occluderManifold.globalShadowManifold.brightness = 1
			if occluderManifold.occluder.Shape == Enum.PartType.Ball then
				occluderManifold.globalShadowManifold.corners = getCornersSphere(occluderManifold.occluder, Lighting:GetSunDirection(), true)
			else
				occluderManifold.globalShadowManifold.corners = getCorners(occluderManifold.occluder, Lighting:GetSunDirection(), true)
			end
			occluderManifold.globalShadowManifold.instanceStorage = {}
			
			-- Apply to pre-existing parent manifold
			table.insert(canvasManifold.occluderManifolds, occluderManifold)
		end
	end
	
	-- Parent to root manifolds
	return canvasManifold
end

local function getRootManifolds()
	local rootManifolds = {}
	
	for _, instance in pairs(BaseFuncs.GetDescendants(workspace)) do
		if instance:IsA("SurfaceGui") and instance:FindFirstChild("isShadowCanvas") then
			if instance.Parent.Shape ~= Enum.PartType.Ball then
				local canvasManifold = newRootManifold(instance)
				
				-- Parent to root manifolds
				table.insert(rootManifolds, canvasManifold)
			end
		end
	end
	
	for _, instance in pairs(BaseFuncs.GetDescendants(workspace.CurrentCamera)) do
		if instance:IsA("SurfaceGui") and instance:FindFirstChild("isShadowCanvas") then
			if instance.Parent.Shape ~= Enum.PartType.Ball then
				local canvasManifold = newRootManifold(instance)
				
				-- Parent to root manifolds
				table.insert(rootManifolds, canvasManifold)
			end
		end
	end
	
	return rootManifolds
end


--# Custom shading on part surfaces
local function newLitCanvases(part)
	-- Declare the manifold
	local partManifold = {}
	
	-- Attributes
	partManifold.canvasManifolds = {}
	partManifold.part = part
	partManifold.partCF = part.CFrame
	
	local lightSources = getNearbyLightSources(part.Position, part.Size.magnitude)
	partManifold.lightSources = {}
	
	for _, li in pairs(lightSources) do
		table.insert(partManifold.lightSources, li)
	end
	
	-- Create SurfaceGui for each Surface for lighting
	for ni, normalId in pairs(lefts) do
		local newCanvas = Instance.new("SurfaceGui")
		newCanvas.CanvasSize = vec2(1, 1)
		newCanvas.Face = ni
		newCanvas.Parent = part
		
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = shadowColor
		frame.Size = udim2(1, 0, 1, 0)
		frame.Parent = newCanvas
		frame.BorderSizePixel = 0
		
		local sid = newCanvas.Face
		local lnormal = Vector3.FromNormalId(sid)
		local normal = partManifold.part.CFrame:vectorToWorldSpace(lnormal)
		local origin = partManifold.part.Position + normal * (lnormal * partManifold.part.Size/2).magnitude
		
		table.insert(partManifold.canvasManifolds, {
			canvas = newCanvas,
			cover = frame,
			canvasWorldSpace = origin
		})
	end
	
	-- Finalize
	return partManifold
end

local function getLitPartManifolds()
	-- Declare the manifold
	local litPartManifolds = {}
	
	-- Generate ALL manifolds
	for _, instance in pairs(BaseFuncs.GetDescendants(workspace)) do
		if instance:FindFirstChild("hasLitSurfaces") and instance.Shape ~= Enum.PartType.Ball then
			table.insert(litPartManifolds, newLitCanvases(instance))
		end
	end
	
	for _, instance in pairs(BaseFuncs.GetDescendants(workspace.CurrentCamera)) do
		if instance:FindFirstChild("hasLitSurfaces") and instance.Shape ~= Enum.PartType.Ball then
			table.insert(litPartManifolds, newLitCanvases(instance))
		end
	end
	
	-- Finalize
	return litPartManifolds
end

local function updateLitPartManifolds(litPartManifolds, onChange)
	for pi, partManifold in pairs(litPartManifolds) do
		-- Re-create world space pos if the part CFrame changes
		local posChanged = false
		if onChange == true then
			if partManifold.partCF ~= partManifold.part.CFrame then
				posChanged = true
			end
		else
			posChanged = true
		end
		
		if posChanged then
			partManifold.partCF = partManifold.part.CFrame
			--print("CF changed")
			for ci, canvasManifold in pairs(partManifold.canvasManifolds) do 
				local sid = canvasManifold.canvas.Face
				local lnormal = Vector3.FromNormalId(sid)
				local normal = partManifold.part.CFrame:vectorToWorldSpace(lnormal)
				local origin = partManifold.part.Position + normal * (lnormal * partManifold.part.Size/2).magnitude

				litPartManifolds[pi].canvasManifolds[ci].normal = normal
				litPartManifolds[pi].canvasManifolds[ci].canvasWorldSpace = origin
			end
		end
		
		-- Detect and reset lights if the position between a lightsource and the part has changed
		local lightPosChanged = false
		
		for _, li in pairs(partManifold.lightSources) do
			if Shadow.AllLightSources[li].posChanged == true then lightPosChanged = true break end
		end
		
		if posChanged == true or lightPosChanged == true then	
			litPartManifolds[pi].lightSources = {}
			for _, li in pairs(getNearbyLightSources(partManifold.part.Position, partManifold.part.Size.magnitude)) do
				table.insert(litPartManifolds[pi].lightSources, li)
			end
	
		end
		
		-- re-calculate all of the lighting
		for ci, canvasManifold in pairs(partManifold.canvasManifolds) do 
			local accumulatedBrightness = 1
			
			if (sunUpdateNeeded == true) or posChanged == true then
				if globalLightingEnabled == true then
					local v = Lighting:GetSunDirection()
					local brightness = math.max(0, canvasManifold.normal:Dot(v))

					accumulatedBrightness = (1 - accumulatedBrightness) + ambient + (brightness * (1 - (transparency) ))
				end
			end
			
			if (posChanged == true or lightPosChanged == true) and localLightingEnabled == true then
				local canvasWorldSpace = litPartManifolds[pi].canvasManifolds[ci].canvasWorldSpace
				
				for _, li in pairs(partManifold.lightSources) do
					local lightSource = Shadow.AllLightSources[li]
					
					local v = (lightSource.pos - canvasManifold.canvasWorldSpace).unit
					local brightness = math.max(0, canvasManifold.normal:Dot(v))
					
					accumulatedBrightness = (1 - accumulatedBrightness) + ambient + (brightness * (1 - (transparency) ))
				end
				
				--print(accumulatedBrightness)
				litPartManifolds[pi].canvasManifolds[ci].cover.BackgroundTransparency = accumulatedBrightness
			else
				litPartManifolds[pi].canvasManifolds[ci].cover.BackgroundTransparency = 1
			end
			
			litPartManifolds[pi].canvasManifolds[ci].cover.BackgroundColor3 = shadowColor
		end
		
	end
	
	
	-- Finalize
	return litPartManifolds
end


--# ShadowMesh Creation
function getTopLeft(hit, sid)
	local lnormal = Vector3.FromNormalId(sid)
	local cf = hit.CFrame + (hit.CFrame:vectorToWorldSpace(lnormal * (hit.Size/2)));
	local modi = (sid == Enum.NormalId.Top or sid == Enum.NormalId.Bottom) and -1 or 1;
	local left = lefts[sid];
	local up = modi * left:Cross(lnormal);
	local tlcf = cf + hit.CFrame:vectorToWorldSpace((up + left) * hit.Size/2);
	return tlcf, Vector2.new((left * hit.Size).magnitude, (up * hit.Size).magnitude),
			hit.CFrame:vectorToWorldSpace(-left),
			hit.CFrame:vectorToWorldSpace(-up), modi;
end;

function isOvereached(normal, highestPoint, lowestPoint, point)
	if not highestPoint or not lowestPoint then return false end	
		
	local projHighestPoint = highestPoint
	local projlowestPoint = lowestPoint
	local projLightPos = normal * point

	local xMet = false
	local yMet = false
	local zMet = false		
	
	if (projLightPos.x >= projlowestPoint.x) and (projLightPos.x <= projHighestPoint.x) then xMet = true end
	if (projLightPos.y >= projlowestPoint.y) and (projLightPos.y <= projHighestPoint.y) then yMet = true end
	if (projLightPos.z >= projlowestPoint.z) and (projLightPos.z <= projHighestPoint.y) then zMet = true end
	--[[print(tostring("highest: ")..projlowestPoint.y)
	print(tostring("light: ")..projLightPos.y)]]
	--print((projLightPos.y >= projlowestPoint.y))
	--print("---------------------")
	if (xMet == true and yMet == true and zMet == true) then return true else return false end
end

function createShadowMesh_Global(shadowManifold, canvasManifold)
	-- Clean up old Instances
	for _, tri in pairs(shadowManifold.instanceStorage) do
		tri:Destroy()
	end
	shadowManifold.instanceStorage = {}

	-- Variables
	local sid = canvasManifold.canvas.Face;
	local lnormal = Vector3.FromNormalId(sid);
	local normal = canvasManifold.part.CFrame:vectorToWorldSpace(lnormal);
	local origin = canvasManifold.part.Position + normal * (lnormal * canvasManifold.part.Size/2).magnitude;
	local tlc, size, right, down, modi = getTopLeft(canvasManifold.part, sid);
	local noPos = false
	--local lightPos = Shadow.AllLightSources[shadowManifold.li].part.Position

	local points = {}
	local pointCornerRef = {}

	for _, corner in next, shadowManifold.corners do
		local lightVector = Lighting:GetSunDirection()
		local dot = normal:Dot(lightVector)

		-- Only render shadows for surface if it can be seen from the light source
		if dot >= 0 then -- CSMG
			local pos = planeIntersect(corner, lightVector, origin, normal)
			
			--local ro = corner - (Lighting:GetSunDirection()*5)
			--local pos = planeIntersect(ro, lightVector, origin, normal)
			
			--[[local elevDist = ((corner) - (origin))*normal
			local pos = planeProject(corner + (lightVector * -elevDist.magnitude), lightVector, origin, normal)]]

			if pos then 
				noPos = true

				local relative = pos - tlc.p;
				local x, y = right:Dot(relative)/size.x, down:Dot(relative)/size.y;
				x, y = modi < 1 and y or x, modi < 1 and x or y;

				local csize = canvasManifold.canvas.CanvasSize;
				local absPosition = Vector2.new(x * csize.x, y * csize.y);		

				table.insert(points, absPosition);
			end

			table.insert(pointCornerRef, {corner, pos})
		--[[else
			local elevDist = ((corner) - (origin))*normal
			local posProject = planeProject(corner + (lightVector * -elevDist.magnitude), lightVector, origin, normal)

			local relative = posProject - tlc.p;
			local x, y = right:Dot(relative)/size.x, down:Dot(relative)/size.y;
			x, y = modi < 1 and y or x, modi < 1 and x or y;

			local csize = canvasManifold.canvas.CanvasSize;
			local absPosition = Vector2.new(x * csize.x, y * csize.y);		

			table.insert(points, absPosition);]]
		end
	end;

	if #points > 2 then	
		local guiSize = canvasManifold.canvas.CanvasSize
		local clippingRect = {
			{guiSize.x, guiSize.y},
			{guiSize.x, 0},
			{0, 0},
			{0, guiSize.y}
		}

		local newPoints = Hull.jarvis(points)
		for i, np in pairs(newPoints) do
			newPoints[i] = {np.x, np.y}
		end
		newPoints = Poly.clipAgainst(newPoints, clippingRect)

		local finalTris = {}

		if #newPoints > 0 then
			finalTris = Poly.triangulate(newPoints)

			for i, t in pairs(finalTris) do
				if t[1] and t[2] and t[3] then
					local ta, tb = Tris(canvasManifold.canvas, shadowColor, transparency, unpack(t))
					table.insert(shadowManifold.instanceStorage, ta);
					table.insert(shadowManifold.instanceStorage, tb);
				end
			end
		end
	end

	return shadowManifold
end

function createShadowMesh(shadowManifold, canvasManifold)
	-- Clean up old Instances
	for _, tri in pairs(shadowManifold.instanceStorage) do
		tri:Destroy()
	end
	shadowManifold.instanceStorage = {}
	
	-- Variables
	local sid = canvasManifold.canvas.Face;
	local lnormal = Vector3.FromNormalId(sid);
	local normal = canvasManifold.part.CFrame:vectorToWorldSpace(lnormal);
	local origin = canvasManifold.part.Position + normal * (lnormal * canvasManifold.part.Size/2).magnitude;
	local tlc, size, right, down, modi = getTopLeft(canvasManifold.part, sid);
	local noPos = false
	local lightPos = Shadow.AllLightSources[shadowManifold.li].part.Position
	
	local points = {}
	local pointCornerRef = {}
	
	for _, corner in next, shadowManifold.corners do
		local lightVector = (lightPos - corner).unit
		local dot = normal:Dot(lightVector)
		
		-- Only render shadows for surface if it can be seen from the light source
		if dot >= 0 then
			local pos = planeIntersect(corner, lightVector, origin, normal)
			
			if pos then 
				noPos = true
				
				local relative = pos - tlc.p;
				local x, y = right:Dot(relative)/size.x, down:Dot(relative)/size.y;
				x, y = modi < 1 and y or x, modi < 1 and x or y;
				
				local csize = canvasManifold.canvas.CanvasSize;
				local absPosition = Vector2.new(x * csize.x, y * csize.y);		

				table.insert(points, absPosition);
			end
			
			table.insert(pointCornerRef, {corner, pos})
		else
			local posProject = planeProject(corner + lightVector * -99999, lightVector, origin, normal)
				
			local relative = posProject - tlc.p;
			local x, y = right:Dot(relative)/size.x, down:Dot(relative)/size.y;
			x, y = modi < 1 and y or x, modi < 1 and x or y;
			
			local csize = canvasManifold.canvas.CanvasSize;
			local absPosition = Vector2.new(x * csize.x, y * csize.y);		
			
			table.insert(points, absPosition);
		end
	end;
	
	if #points > 2 then	
		local guiSize = canvasManifold.canvas.CanvasSize
		local clippingRect = {
			{guiSize.x, guiSize.y},
			{guiSize.x, 0},
			{0, 0},
			{0, guiSize.y}
		}
		
		local newPoints = Hull.jarvis(points)
		for i, np in pairs(newPoints) do
			newPoints[i] = {np.x, np.y}
		end
		newPoints = Poly.clipAgainst(newPoints, clippingRect)
		
		local finalTris = {}
		
		if #newPoints > 0 then
			finalTris = Poly.triangulate(newPoints)
		
			for i, t in pairs(finalTris) do
				if t[1] and t[2] and t[3] then
					local ta, tb = Tris(canvasManifold.canvas, shadowColor, transparency, unpack(t))
					table.insert(shadowManifold.instanceStorage, ta);
					table.insert(shadowManifold.instanceStorage, tb);
				end
			end
		end
	end
	
	return shadowManifold
end


--# Final collected functions
function Shadow.getRootManifolds()
	return getRootManifolds()
end

function Shadow.createAllShadowMeshes(rootManifolds)
	for ci, canvasManifold in pairs(rootManifolds) do
		for oi, occluderManifold in pairs(canvasManifold.occluderManifolds) do
			for si, shadowManifold in pairs(occluderManifold.shadowManifolds) do
				if localLightingEnabled == true then
					shadowManifold = createShadowMesh(shadowManifold, canvasManifold)
				end
			end
			if globalLightingEnabled == true then
				createShadowMesh_Global(occluderManifold.globalShadowManifold, canvasManifold)
			end
		end
	end
	
	--return rootManifolds
end
local num1 = 0
function Shadow.updateRootManifolds(rootManifolds)
	-- Update the lighting value settings
	updateLighting()

	-- Interate through manifolds
	for ci, canvasManifold in pairs(rootManifolds) do
		-- Re-compute ENTIRE shadow manifold if canvas position changes.
		--[[print(tostring(canvasManifold.part.CFrame.x)..", "..tostring(canvasManifold.part.CFrame.y)..", "..tostring(canvasManifold.part.CFrame.z))
		print(tostring(canvasManifold.partCF.x)..", "..tostring(canvasManifold.partCF.y)..", "..tostring(canvasManifold.partCF.z))
		print("------------------------------------------------------------------------------------------")]]
		
		-- Update ONLY if part CF changed
		if canvasManifold.part.CFrame ~= canvasManifold.partCF then
			-- Delete old instance storage
			for _, instance in pairs(canvasManifold.canvas:GetChildren()) do
				if (not instance:IsA("BoolValue")) and (not instance:IsA("StringValue")) and (not instance:IsA("Frame")) then
					instance:Destroy()
				end
			end
			
			-- Remake the entire canvas manifold.
			rootManifolds[ci] = newRootManifold(canvasManifold.canvas)

			-- Re-render shadows
			for oi, occluderManifold in pairs(canvasManifold.occluderManifolds) do
				if globalLightingEnabled == true then
					if rootManifolds[ci].occluderManifolds[oi].occluder.Shape == Enum.PartType.Ball then
						rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCornersSphere(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
					else
						rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCorners(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
					end

					rootManifolds[ci].occluderManifolds[oi].globalShadowManifold = createShadowMesh_Global(rootManifolds[ci].occluderManifolds[oi].globalShadowManifold, rootManifolds[ci])
				end
				
				if localLightingEnabled == true then
					for si, shadowManifold in pairs(occluderManifold.shadowManifolds) do
						rootManifolds[ci].occluderManifolds[oi].shadowManifolds[si] = createShadowMesh(shadowManifold, canvasManifold)
					end
				end
				
			end
		else
			for oi, occluderManifold in pairs(canvasManifold.occluderManifolds) do
				local globalShadowMeshUpdated = false
				local localShadowMeshUpdated = false
				
				-- Re-compute ALL shadow manifolds if the occluder has changed position or rotation.
				if occluderManifold.occluder.CFrame ~= occluderManifold.occluderCF then
					occluderManifold.occluderCF = occluderManifold.occluder.CFrame
					
					-- Delete old instance storage
					for si, shadowManifold in pairs(occluderManifold.shadowManifolds) do
						for _, instance in pairs(shadowManifold.instanceStorage) do
							instance:Destroy()
						end 
						shadowManifold.instanceStorage = {}
					end
					
					-- Actual re-computation of shadow manifolds
					occluderManifold.shadowManifolds = {}
					--[[local lightSources = getNearbyLightSources(occluderManifold.occluder.Position)
					
					for _, light in pairs(lightSources) do
						local lightPart = light.Parent
						local shadowManifold = {}
						shadowManifold.lightPart = lightPart
						shadowManifold.lightPos = lightPart.Position
						shadowManifold.lightNum = #lightSources
						shadowManifold.corners = getCorners(occluderManifold.occluder, lightPart.Position)
						shadowManifold.instanceStorage = {}
						table.insert(occluderManifold.shadowManifolds, shadowManifold)
					end]]
					
					if localLightingEnabled == true and localShadowMeshUpdated == false then
						localShadowMeshUpdated = true
						
						local lightSources = getNearbyLightSources(occluderManifold.occluder.Position)
				
						for _, li in pairs(lightSources) do
							local shadowManifold = {}
							shadowManifold.li = li
							shadowManifold.brightness = 1
							if occluderManifold.occluder.Shape == Enum.PartType.Ball then
								shadowManifold.corners = getCornersSphere(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							else
								shadowManifold.corners = getCorners(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							end
							shadowManifold.instanceStorage = {}
							
							-- Apply current SM to shadowManifolds
							table.insert(occluderManifold.shadowManifolds, shadowManifold)
						end
						
						-- Re-render shadows
						for si, shadowManifold in pairs(occluderManifold.shadowManifolds) do
							shadowManifold = createShadowMesh(shadowManifold, canvasManifold)
						end
					end
					
					-- Re-render global shadows
					if globalShadowMeshUpdated == false then
						globalShadowMeshUpdated = true

						if globalLightingEnabled == true then
							if rootManifolds[ci].occluderManifolds[oi].occluder.Shape == Enum.PartType.Ball then
								rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCornersSphere(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
							else
								rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCorners(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
							end

							rootManifolds[ci].occluderManifolds[oi].globalShadowManifold = createShadowMesh_Global(rootManifolds[ci].occluderManifolds[oi].globalShadowManifold, canvasManifold)
						else
							for _, item in pairs(rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.instanceStorage) do
								if item then item:Destroy() end
							end
							rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.instanceStorage = {}
						end
					end
				end
				
				-- Re-compute SPECIFIC shadow manifold if light position changes
				for si, shadowManifold in pairs(occluderManifold.shadowManifolds) do
					--local lightPos = Shadow.AllLightSources[shadowManifold.li].pos
					
					if Shadow.AllLightSources[shadowManifold.li].posChanged == true then
						
						-- Delete old instance storage
						for _, instance in pairs(shadowManifold.instanceStorage) do
							instance:Destroy()
						end 
						shadowManifold.instanceStorage = {}
						
						if localLightingEnabled == true and localShadowMeshUpdated == false then
							localShadowMeshUpdated = true
							--[[ Update shadow manifold variables
							shadowManifold.lightPos = shadowManifold.lightPart.Position]]
							--shadowManifold.corners = getCorners(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].pos)
							if occluderManifold.occluder.Shape == Enum.PartType.Ball then
								shadowManifold.corners = getCornersSphere(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							else
								shadowManifold.corners = getCorners(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							end
							shadowManifold.instanceStorage = {}
							
							-- Re-render shadow for specific manifold
							shadowManifold = createShadowMesh(shadowManifold, canvasManifold)
							
							-- Apply shadow manifold
							occluderManifold.shadowManifolds[si] = shadowManifold
						end
					end
					
					
					-- Update shadows if light enabled/disabled
					if localUpdateNeeded == true then
						localShadowMeshUpdated = true
						
						if localLightingEnabled == true then
							-- Delete old instance storage
							for _, instance in pairs(shadowManifold.instanceStorage) do
								instance:Destroy()
							end 
							shadowManifold.instanceStorage = {}

							if occluderManifold.occluder.Shape == Enum.PartType.Ball then
								shadowManifold.corners = getCornersSphere(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							else
								shadowManifold.corners = getCorners(occluderManifold.occluder, Shadow.AllLightSources[shadowManifold.li].part.Position)
							end
							shadowManifold.instanceStorage = {}

							-- Re-render shadow for specific manifold
							shadowManifold = createShadowMesh(shadowManifold, canvasManifold)

							-- Apply shadow manifold
							occluderManifold.shadowManifolds[si] = shadowManifold
						else
							for _, instance in pairs(shadowManifold.instanceStorage) do
								instance:Destroy()
							end 
							shadowManifold.instanceStorage = {}
						end
					end
					
				end
				
				-- Check if sun dir changed or sun deleted
				if sunUpdateNeeded == true then
					if globalLightingEnabled == true then
						if rootManifolds[ci].occluderManifolds[oi].occluder.Shape == Enum.PartType.Ball then
							rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCornersSphere(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
						else
							rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.corners = getCorners(rootManifolds[ci].occluderManifolds[oi].occluder, Lighting:GetSunDirection(), true)
						end

						rootManifolds[ci].occluderManifolds[oi].globalShadowManifold = createShadowMesh_Global(rootManifolds[ci].occluderManifolds[oi].globalShadowManifold, canvasManifold)
					else
						for _, item in pairs(rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.instanceStorage) do
							if item then item:Destroy() end
						end
						rootManifolds[ci].occluderManifolds[oi].globalShadowManifold.instanceStorage = {}
					end
				end
				
				-- Apply global occluder manifold
				rootManifolds[ci].occluderManifold = occluderManifold
			end
		end
	end
	
	prevSunDir = Lighting:GetSunDirection()
		
	return rootManifolds
end

function Shadow.getLitPartManifolds()
	return getLitPartManifolds()
end

function Shadow.updateLitPartManifolds(manifolds)
	return updateLitPartManifolds(manifolds)
end

function Shadow.lightPartManifolds(litPartManifolds)
	return updateLitPartManifolds(litPartManifolds, false)
end


--# Utility functions - making parts occluders
function scanForSurfaceGuiSide(location, face)
	for _, gui in pairs(location:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			if gui.Face == face and gui:FindFirstChild("isShadowCanvas") then return true end
		end
	end
end

function newFuncSurfaceGui(location, face, bool)
	local surfaceGui = Instance.new("SurfaceGui", location)
	surfaceGui.Name = "ShadowCanvasGui"
	surfaceGui.CanvasSize = Vector2.new(10000, 10000)
	surfaceGui.Face = face
	local boolVal = Instance.new("BoolValue", surfaceGui)
	boolVal.Name = "isShadowCanvas"
	boolVal.Value = bool
end

function Shadow.setPartProperty(part, property, bool)
	if part:IsA("BasePart") then
		if type(bool) ~= "table" then
			if property ~= "isShadowCanvasAll" and property ~= "isShadowCanvasLeft" and property ~= "isShadowCanvasRight" and property ~= "isShadowCanvasTop" and property ~= "isShadowCanvasBottom" and property ~= "isShadowCanvasFront" and property ~= "isShadowCanvasBack" then
				local propVal = part:FindFirstChild(property)
				
				if bool == false then
					if propVal then
						propVal:Destroy()
					end
				else
					if not propVal then
						propVal = Instance.new("BoolValue", part)
						propVal.Name = property
					end
				end
				
			else
				if property == "isShadowCanvasAll" then
					for face, vec in pairs(lefts) do
						local relativeGui = scanForSurfaceGuiSide(part, face)
						if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
					end
				elseif property == "isShadowCanvasTop" then
					local face = Enum.NormalId.Top
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				elseif property == "isShadowCanvasBottom" then
					local face = Enum.NormalId.Bottom
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				elseif property == "isShadowCanvasRight" then
					local face = Enum.NormalId.Right
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				elseif property == "isShadowCanvasLeft" then
					local face = Enum.NormalId.Left
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				elseif property == "isShadowCanvasFront" then
					local face = Enum.NormalId.Front
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				elseif property == "isShadowCanvasBack" then
					local face = Enum.NormalId.Back
					local relativeGui = scanForSurfaceGuiSide(part, face)
					if relativeGui then --[[relativeGui.Value = bool]] else newFuncSurfaceGui(part, face, bool) end
				end
			end
		end
	end
end

function Shadow.setModelProperty(model, property, bool)
	for _, part in pairs(BaseFuncs.GetDescendants(model)) do
		Shadow.setPartProperty(part, property, bool)
	end
end


--# Misc Functions
function Shadow.updateDescendants(location)
	Shadow.allDescendants = {}
	for _, part in pairs(BaseFuncs.GetDescendants(location)) do
		if part:IsA("BasePart") then table.insert(Shadow.allDescendants, part) end
	end
end


--# Finalize
return Shadow
