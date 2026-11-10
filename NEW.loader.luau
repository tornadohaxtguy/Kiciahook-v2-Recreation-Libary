--==========================================================================
--  Kiciahook V2 Recreated  -  Rivals
--  Hell yes uh hi
--==========================================================================

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local TITLE = "Kiciahook V2 | Rivals"
local GUI_NAME = "KiciaUI"
local FONT = Font.fromName("Ubuntu")
local FONT_ENUM = Enum.Font.Ubuntu
local DEFAULT_TEXT_SIZE = 11
local TEXT_SIZE = DEFAULT_TEXT_SIZE
local textSizeBases = setmetatable({}, { __mode = "k" })
local ROW_TOGGLE = 19
local ROW_SLIDER = 30
local ROW_FIELD = 24
local SECTION_HEADER = 23
local SECTION_GAP = 5
local SWATCH_WIDTH = 40
local SWATCH_PITCH = 43.5
local POPUP_ROW = 18
local POPUP_MAX_ROWS = 8
local LABEL_OFFSET = 18
local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 450
local FIT_MARGIN = 8
local MIN_FIT_SCALE = 0.25
local REFERENCE_WIDTH = 1920
local REFERENCE_HEIGHT = 1080
local DEFAULT_SCALE = 1.0 -- Matches the reference menu size at 1920x1080
local MIN_SHRINK = 0.6
local MAX_GROWTH = 1.6
local RESIZE_OUTSIDE = 8
local RESIZE_INSIDE = 6
local RESIZE_TOP_INSIDE = 2
local BIND_MENU_ROW = 14
local BIND_MENU_TEXT = 12
local MOBILE_BOX_WIDTH = 64
local MOBILE_BOX_HEIGHT = 26
local TAP_SLOP = 6
local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local ACCENT = Color3.fromRGB(220, 0, 195)
local ACCENT_DARK = Color3.fromRGB(92, 0, 82)
local SETTINGS_HIGHLIGHT = ACCENT
local MAIN = Color3.fromRGB(31, 31, 31)
local BACKGROUND = Color3.fromRGB(26, 26, 26)
local SECTION = Color3.fromRGB(24, 24, 24)
local OUTLINE = Color3.fromRGB(50, 50, 50)
local CONTROL = Color3.fromRGB(32, 32, 32)
local FIELD = Color3.fromRGB(27, 27, 27)
local SHADE_CONTROL = Color3.fromRGB(196, 196, 196)
local SHADE_ACCENT = Color3.fromRGB(136, 136, 136)
local RED = Color3.fromRGB(255, 0, 0)
local GREEN = Color3.fromRGB(0, 255, 0)
local CYAN = Color3.fromRGB(0, 216, 255)
local GREY = Color3.fromRGB(180, 180, 180)
local PALE_YELLOW = Color3.fromRGB(255, 255, 160)
local GOLD = Color3.fromRGB(220, 200, 10)
local BIND_MODES = { "Hold", "Toggle", "Always" }
local MATERIALS = { "ForceField", "Neon", "Glass", "SmoothPlastic" }

-- Control callbacks are protected so a user callback error cannot break the UI.
local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[KiciaUI] Control callback failed: " .. tostring(err))
    end
end

-- Linoria SaveManager bridge:
-- This UI uses custom controls, so each control is exposed through Linoria's
-- Toggle/Options object contract (Value, Type, SetValue).
local configRegistry = { Toggles = {}, Options = {} }
local nextConfigObjectId = 0

local function registerConfigObject(object, isToggle, stableKey)
    -- Stable keys let newly added controls join the config system without
    -- shifting the sequential IDs already used by existing saved configs.
    local index
    if stableKey and tostring(stableKey) ~= "" then
        index = "KiciaUI_Stable_" .. tostring(stableKey)
    else
        nextConfigObjectId = nextConfigObjectId + 1
        index = string.format("KiciaUI_%s_%04d", isToggle and "Toggle" or "Option", nextConfigObjectId)
    end

    if isToggle then
        configRegistry.Toggles[index] = object
    else
        configRegistry.Options[index] = object
    end
    return index
end

local configState = {
    Items = {},
    Selected = nil,
    Observers = {},
}

-- Text entered in the config-name field is consumed by the Create button.
local configNameValue = ""
local configNameTextBox = nil

local SaveManager
local SaveManagerError

local accentBindings = {}
local accentGradients = {}
local accentRefreshers = {}

local function notifyConfigObservers(itemsChanged)
    for _, observer in ipairs(configState.Observers) do
        observer(itemsChanged == true)
    end
end

local function stripJsonExtension(name)
    name = tostring(name or "")
    if name:sub(-5):lower() == ".json" then
        return name:sub(1, -6)
    end
    return name
end

local function hasConfigFile(name)
    for _, item in ipairs(configState.Items) do
        if item == name then
            return true
        end
    end
    return false
end

local function refreshConfigItems(preferred)
    if not SaveManager then
        if #configState.Items == 0 then
            table.insert(configState.Items, "default.json")
        end
        configState.Selected = configState.Selected or configState.Items[1]
        notifyConfigObservers(true)
        return false, SaveManagerError or "Linoria SaveManager is unavailable"
    end

    local ok, names = pcall(function()
        return SaveManager:RefreshConfigList()
    end)
    if not ok then
        return false, tostring(names)
    end

    table.clear(configState.Items)
    for _, name in ipairs(names) do
        table.insert(configState.Items, tostring(name) .. ".json")
    end

    if #configState.Items == 0 then
        table.insert(configState.Items, "default.json")
    end

    if preferred and hasConfigFile(preferred) then
        configState.Selected = preferred
    elseif not configState.Selected or not hasConfigFile(configState.Selected) then
        configState.Selected = hasConfigFile("default.json") and "default.json" or configState.Items[1]
    end

    notifyConfigObservers(true)
    return true
end

local function selectConfig(name)
    if hasConfigFile(name) then
        configState.Selected = name
        notifyConfigObservers(false)
        return true
    end
    return false
end

local function callSaveManager(method, ...)
    if not SaveManager then
        return false, SaveManagerError or "Linoria SaveManager is unavailable"
    end

    local fn = SaveManager[method]
    if type(fn) ~= "function" then
        return false, "SaveManager method is missing: " .. tostring(method)
    end

    local ok, success, err = pcall(fn, SaveManager, ...)
    if not ok then
        return false, tostring(success)
    end
    if success ~= true then
        return false, tostring(err or "operation failed")
    end
    return true
end

local function saveConfigNamed(name)
    local bareName = stripJsonExtension(name)
    if bareName == "" or bareName:find("/", 1, true) or bareName:find("\\", 1, true) then
        return false, "invalid config name"
    end

    local ok, err = callSaveManager("Save", bareName)
    if not ok then
        warn("[KiciaUI] Save failed: " .. tostring(err))
        return false, err
    end

    refreshConfigItems(bareName .. ".json")
    return true
end

local function createConfigEntry(name)
    local candidate = stripJsonExtension(name)
    candidate = candidate:gsub("^%s+", ""):gsub("%s+$", "")

    if candidate == "" then
        warn("[KiciaUI] Enter a config name before pressing Create.")
        return nil
    end

    if candidate:find("/", 1, true)
        or candidate:find("\\", 1, true)
        or candidate:find("%c") then
        warn("[KiciaUI] Config names cannot contain slashes or control characters.")
        return nil
    end

    local fileName = candidate .. ".json"
    if hasConfigFile(fileName) then
        warn("[KiciaUI] A config with that name already exists. Choose another name.")
        return nil
    end

    if saveConfigNamed(candidate) then
        selectConfig(fileName)
        configNameValue = ""
        if configNameTextBox then
            configNameTextBox.Text = ""
        end
        return fileName
    end

    return nil
end

local function deleteSelectedConfig()
    if not configState.Selected or configState.Selected == "default.json" then
        return false
    end
    if type(delfile) ~= "function" or not SaveManager then
        warn("[KiciaUI] Delete requires the executor delfile API.")
        return false
    end

    local path = SaveManager.Folder .. "/settings/" .. stripJsonExtension(configState.Selected) .. ".json"
    local ok, err = pcall(delfile, path)
    if not ok then
        warn("[KiciaUI] Delete failed: " .. tostring(err))
        return false
    end

    configState.Selected = nil
    refreshConfigItems()
    return true
end

-- Use the repository's actual Linoria SaveManager addon. The full Linoria
-- Library.lua is intentionally not loaded because this recreation already
-- owns its ScreenGui and custom controls.
do
    local hasFileApi =
        type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
        and type(listfiles) == "function"
        and type(isfolder) == "function"
        and type(makefolder) == "function"

    if not hasFileApi then
        SaveManagerError = "executor file APIs are unavailable (writefile/readfile/isfile/listfiles/isfolder/makefolder)"
    elseif type(loadstring) ~= "function" then
        SaveManagerError = "loadstring is unavailable"
    else
        local sourceUrl = "https://raw.githubusercontent.com/tornadohaxtguy/Kiciahook-v2-Recreation-Libary/6c07c913279b47f9e4171b339198c333afb82377/addons/SaveManager.lua"
        local fetched, source = pcall(function()
            return game:HttpGet(sourceUrl)
        end)

        if not fetched then
            SaveManagerError = "could not download Linoria SaveManager: " .. tostring(source)
        else
            local chunk, compileError = loadstring("local Toggles, Options = ...\n" .. source)
            if not chunk then
                SaveManagerError = "could not compile Linoria SaveManager: " .. tostring(compileError)
            else
                local loaded, manager = pcall(chunk, configRegistry.Toggles, configRegistry.Options)
                if not loaded then
                    SaveManagerError = "could not initialize Linoria SaveManager: " .. tostring(manager)
                else
                    SaveManager = manager
                    local setupOk, setupError = pcall(function()
                        SaveManager:SetFolder("LinoriaLibSettings")
                        SaveManager:SetLibrary({
                            Notify = function(_, message)
                                warn("[KiciaUI] " .. tostring(message))
                            end,
                        })
                    end)
                    if setupOk then
                        refreshConfigItems()
                    else
                        SaveManager = nil
                        SaveManagerError = "could not configure Linoria SaveManager: " .. tostring(setupError)
                    end
                end
            end
        end
    end

    if not SaveManager then
        warn("[KiciaUI] Config persistence unavailable: " .. tostring(SaveManagerError))
        if #configState.Items == 0 then
            table.insert(configState.Items, "default.json")
        end
        configState.Selected = configState.Items[1]
    end
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
})
local function create(className, properties)
	local instance = Instance.new(className)
	for name, value in pairs(properties) do
		if name ~= "Parent" then
			instance[name] = value
			if name == "BackgroundColor3" or name == "BorderColor3" or name == "TextColor3" then
				local role
				if value == ACCENT or value == SETTINGS_HIGHLIGHT then
					role = "accent"
				elseif value == ACCENT_DARK then
					role = "dark"
				end
				if role then
					table.insert(accentBindings, { Object = instance, Property = name, Role = role })
				end
			end
		end
	end
	instance.Parent = properties.Parent
	return instance
end

local function box(parent, position, size, color, borderColor, inset)
	return create("Frame", {
		BackgroundColor3 = color,
		BorderColor3 = borderColor or BLACK,
		BorderMode = inset and Enum.BorderMode.Inset or Enum.BorderMode.Outline,
		BorderSizePixel = borderColor and 1 or 0,
		Position = position,
		Size = size,
		Parent = parent,
	})
end

local function panel(parent, position, size)
	return create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	})
end

local function well(parent, position, size, color)
	local outer = box(parent, position, size, color, BLACK)
	local inner = box(outer, UDim2.new(), UDim2.fromScale(1, 1), color, OUTLINE, true)
	return outer, inner
end

local function shade(frame, bottom)
	local gradient = create("UIGradient", {
		Color = ColorSequence.new(WHITE, bottom),
		Rotation = 90,
		Parent = frame,
	})
	if bottom == SHADE_ACCENT then
		table.insert(accentGradients, gradient)
	end
	return gradient
end

local function setAccentColor(color)
	if typeof(color) ~= "Color3" then
		return
	end

	ACCENT = color
	SETTINGS_HIGHLIGHT = color
	local hue, saturation, brightness = color:ToHSV()
	ACCENT_DARK = Color3.fromHSV(hue, saturation, math.max(0.12, brightness * 0.42))
	SHADE_ACCENT = Color3.fromHSV(hue, saturation * 0.45, math.clamp(brightness * 0.82, 0, 1))

	for _, binding in ipairs(accentBindings) do
		local value = binding.Role == "dark" and ACCENT_DARK or ACCENT
		pcall(function()
			binding.Object[binding.Property] = value
		end)
	end

	for _, gradient in ipairs(accentGradients) do
		pcall(function()
			gradient.Color = ColorSequence.new(WHITE, SHADE_ACCENT)
		end)
	end

	for _, refresh in ipairs(accentRefreshers) do
		refresh()
	end
end

local function textObject(className, parent, text, position, size, alignment)
	local object = create(className, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FONT,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = WHITE,
		TextSize = TEXT_SIZE,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		Parent = parent,
	})
	-- Store the size at the default setting so later changes scale proportionally.
	textSizeBases[object] = DEFAULT_TEXT_SIZE
	return object
end

local function textWidth(text, size)
	return TextService:GetTextSize(text, size, FONT_ENUM, Vector2.new(1000, 20)).X
end

local function hitbox(parent, position, size)
	return create("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Text = "",
		Parent = parent,
	})
end

local function accentFill(parent, size)
	local fill = box(parent, UDim2.new(), size, ACCENT, ACCENT_DARK, true)
	shade(fill, SHADE_ACCENT)
	return fill
end

local function clippedText(parent, text, position, size)
	local clip = panel(parent, position, size)
	clip.ClipsDescendants = true
	textObject("TextLabel", clip, text, UDim2.new(), UDim2.new(0, 400, 1, 0))
	return clip
end

local function roundTo(value, decimals)
	local factor = 10 ^ decimals
	return math.floor(value * factor + 0.5) / factor
end

local function isPress(input)

	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch

end

local function isPointerPress(input)

	return isPress(input) or input.UserInputType == Enum.UserInputType.MouseButton2

end

local function isSamePress(input, press)

	if press.UserInputType == Enum.UserInputType.Touch then

		return input == press

	end

	return input.UserInputType == press.UserInputType

end

local function isInside(object, position)

	local origin = object.AbsolutePosition

	local size = object.AbsoluteSize

	return position.X >= origin.X

		and position.X <= origin.X + size.X

		and position.Y >= origin.Y

		and position.Y <= origin.Y + size.Y

end

local function inputName(input)

	local kind = input.UserInputType

	if kind == Enum.UserInputType.Keyboard or string.sub(kind.Name, 1, 7) == "Gamepad" then

		if input.KeyCode ~= Enum.KeyCode.Unknown then

			return input.KeyCode.Name

		end

		return nil

	end

	if

		kind == Enum.UserInputType.MouseButton1

		or kind == Enum.UserInputType.MouseButton2

		or kind == Enum.UserInputType.MouseButton3

	then

		return kind.Name

	end

	return nil

end

local function trackDrag(press, onMove, onRelease)

	local moved

	local released

	moved = UserInputService.InputChanged:Connect(function(input)

		if input == press or input.UserInputType == Enum.UserInputType.MouseMovement then

			onMove(input.Position)

		end

	end)

	released = UserInputService.InputEnded:Connect(function(input)

		if isSamePress(input, press) then

			moved:Disconnect()

			released:Disconnect()

			if onRelease then

				onRelease()

			end

		end

	end)

end

local function bindDrag(handle, onMove, onPress, onRelease)

	handle.InputBegan:Connect(function(input)

		if isPress(input) then

			if onPress then

				onPress(input)

			end

			onMove(input.Position)

			trackDrag(input, onMove, onRelease)

		end

	end)

end

local function bindHover(handle, target)

	handle.MouseEnter:Connect(function()

		target.BorderColor3 = ACCENT

	end)

	handle.MouseLeave:Connect(function()

		target.BorderColor3 = OUTLINE

	end)

end

local previous = playerGui:FindFirstChild(GUI_NAME)

if previous then

	previous:Destroy()

end

local screen = create("ScreenGui", {

	DisplayOrder = 1000,

	Name = GUI_NAME,

	ResetOnSpawn = false,

	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

	Parent = playerGui,

})

-- FontFace supports the full font families. FONT_ENUM is used only by
-- TextService:GetTextSize, whose measurement API still accepts Enum.Font.
local FONT_FACE_NAMES = {
	Ubuntu = "Ubuntu",
	Gotham = "Montserrat",
	Arial = "Arimo",
	Roboto = "Roboto",
	Code = "Inconsolata",
	SourceSans = "SourceSansPro",
}

local FONT_MEASURE_ENUMS = {
	Ubuntu = Enum.Font.Ubuntu,
	Gotham = Enum.Font.Gotham,
	Arial = Enum.Font.Arial,
	Roboto = Enum.Font.SourceSans,
	Code = Enum.Font.Code,
	SourceSans = Enum.Font.SourceSans,
}

local function isTextObject(object)
	return object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")
end

local function scaledTextSize(baseSize)
	local scale = TEXT_SIZE / DEFAULT_TEXT_SIZE
	return math.max(1, math.floor((tonumber(baseSize) or DEFAULT_TEXT_SIZE) * scale + 0.5))
end

local function setBaseTextSize(object, baseSize)
	if not object or not isTextObject(object) then
		return
	end
	local numericSize = tonumber(baseSize) or DEFAULT_TEXT_SIZE
	textSizeBases[object] = numericSize
	object.TextSize = scaledTextSize(numericSize)
end

local function applyTypography(previousTextSize)
	local previousScale = (tonumber(previousTextSize) or TEXT_SIZE) / DEFAULT_TEXT_SIZE
	for _, object in ipairs(screen:GetDescendants()) do
		if isTextObject(object) then
			local baseSize = textSizeBases[object]
			if not baseSize then
				baseSize = object.TextSize / math.max(previousScale, 0.01)
				textSizeBases[object] = baseSize
			end
			object.FontFace = FONT
			object.TextSize = scaledTextSize(baseSize)
		end
	end
end

local function setFont(value)
	if type(value) == "table" then
		value = value[1]
	end
	local displayName = tostring(value or "")
	local familyName = FONT_FACE_NAMES[displayName]
	local measureFont = FONT_MEASURE_ENUMS[displayName]
	if not familyName or not measureFont then
		warn("[KiciaUI] Unknown font: " .. displayName)
		return
	end
	local ok, selected = pcall(function()
		return Font.fromName(familyName)
	end)
	if not ok then
		warn("[KiciaUI] Could not create font " .. displayName .. ": " .. tostring(selected))
		return
	end
	FONT = selected
	FONT_ENUM = measureFont
	applyTypography(TEXT_SIZE)
end

local function setTextSize(value)
	local numericSize = tonumber(value)
	if not numericSize then
		return
	end
	local previous = TEXT_SIZE
	TEXT_SIZE = math.clamp(math.floor(numericSize + 0.5), 6, 26)
	applyTypography(previous)
end

local topInset = GuiService:GetGuiInset()

local window = box(

	screen,

	UDim2.new(0.5, 0, 0.5, -topInset.Y / 2),

	UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),

	BLACK

)

window.Active = true

window.AnchorPoint = Vector2.new(0.5, 0.5)

local menuScale = create("UIScale", { Parent = window })

local customScale

local function getScaleLimits()

	local available = screen.AbsoluteSize

	local fullHeight = available.Y + topInset.Y

	local fit = math.max(

		MIN_FIT_SCALE,

		math.min((available.X - FIT_MARGIN * 2) / WINDOW_WIDTH, (fullHeight - FIT_MARGIN * 2) / WINDOW_HEIGHT)

	)

	local proportional = math.min(available.X / REFERENCE_WIDTH, fullHeight / REFERENCE_HEIGHT)

	local default = math.min(fit, DEFAULT_SCALE * math.max(1, proportional))

	return default, default * MIN_SHRINK, math.min(fit, default * MAX_GROWTH)

end

local function keepWindowOnScreen()

	local limit = screen.AbsoluteSize

	if limit.X <= 0 or limit.Y <= 0 then

		return

	end

	local halfWidth = WINDOW_WIDTH * menuScale.Scale / 2

	local halfHeight = WINDOW_HEIGHT * menuScale.Scale / 2

	local position = window.Position

	local minimumY = halfHeight - topInset.Y

	local centerX = math.clamp(limit.X / 2 + position.X.Offset, halfWidth, math.max(halfWidth, limit.X - halfWidth))

	local centerY = math.clamp(limit.Y / 2 + position.Y.Offset, minimumY, math.max(minimumY, limit.Y - halfHeight))

	window.Position = UDim2.new(0.5, centerX - limit.X / 2, 0.5, centerY - limit.Y / 2)

end

local function applyScale()

	local default, lower, upper = getScaleLimits()

	menuScale.Scale = customScale and math.clamp(customScale, lower, upper) or default

	keepWindowOnScreen()

end

applyScale()

screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)

local chrome = box(window, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), MAIN, ACCENT, true)

textObject("TextLabel", chrome, TITLE, UDim2.fromOffset(6, 1), UDim2.new(1, -12, 0, 20))

local bodyOuter = box(chrome, UDim2.fromOffset(5, 19), UDim2.new(1, -10, 1, -24), BACKGROUND, OUTLINE, true)

local body = box(bodyOuter, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), BACKGROUND, BLACK, true)

local overlay = panel(screen, UDim2.new(), UDim2.fromScale(1, 1))

overlay.ZIndex = 10

local connections = {}

local activePopup

local activeCapture

local menuKey = "RightShift"

local function closePopup()

	if activePopup then

		local popup = activePopup

		activePopup = nil

		popup.Frame:Destroy()

		if popup.OnClose then

			popup.OnClose()

		end

	end

end

local function isPopupAnchor(object)

	return activePopup ~= nil and activePopup.Anchor == object

end

local function createPopup(width, height, color)

	local frame, inner = well(overlay, UDim2.new(), UDim2.fromOffset(width, height), color)

	create("UIScale", { Scale = menuScale.Scale, Parent = frame })

	return frame, inner

end

local function placePopup(frame, anchor, width, height, alignRight)

	local scale = menuScale.Scale

	local scaledWidth = width * scale

	local scaledHeight = height * scale

	local origin = anchor.AbsolutePosition

	local limit = screen.AbsoluteSize

	local left = alignRight and origin.X + anchor.AbsoluteSize.X - scaledWidth or origin.X

	local x = math.clamp(left, 2, math.max(2, limit.X - scaledWidth - 2))

	local y = origin.Y + anchor.AbsoluteSize.Y + 3

	if y + scaledHeight > limit.Y then

		y = math.max(2, origin.Y - scaledHeight - 3)

	end

	frame.Position = UDim2.fromOffset(x, y)

end

local function openList(anchor, options, isSelected, onPick, layout)

	closePopup()

	local rowHeight = layout.RowHeight or POPUP_ROW

	local width = layout.Width

	local height = math.min(#options, POPUP_MAX_ROWS) * rowHeight + 2

	local frame, inner = createPopup(width, height, FIELD)

	local list = create("ScrollingFrame", {

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		CanvasSize = UDim2.fromOffset(0, #options * rowHeight),

		ElasticBehavior = Enum.ElasticBehavior.Never,

		Position = UDim2.fromOffset(1, 1),

		ScrollBarThickness = 0,

		ScrollingDirection = Enum.ScrollingDirection.Y,

		Size = UDim2.new(1, -2, 1, -2),

		Parent = inner,

	})

	local buttons = {}

	local function refresh()

		for index, button in ipairs(buttons) do

			button.TextColor3 = isSelected(options[index]) and ACCENT or WHITE

		end

	end

	for index, option in ipairs(options) do

		local button = textObject(

			"TextButton",

			list,

			option,

			UDim2.fromOffset(0, (index - 1) * rowHeight),

			UDim2.new(1, 0, 0, rowHeight)

		)

		button.AutoButtonColor = false

		button.BackgroundColor3 = MAIN

		setBaseTextSize(button, layout.TextSize or DEFAULT_TEXT_SIZE)

		create("UIPadding", { PaddingLeft = UDim.new(0, 5), Parent = button })

		button.MouseEnter:Connect(function()

			button.BackgroundTransparency = 0

		end)

		button.MouseLeave:Connect(function()

			button.BackgroundTransparency = 1

		end)

		button.Activated:Connect(function()

			onPick(option)

			refresh()

		end)

		buttons[index] = button

	end

	refresh()

	placePopup(frame, anchor, width, height, layout.AlignRight)

	activePopup = { Frame = frame, Anchor = anchor, OnClose = layout.OnClose }

end

local function openPicker(anchor, initial, onChange)

	closePopup()

	local hue, saturation, brightness = initial:ToHSV()

	local width = 186

	local height = 172

	local frame, inner = createPopup(width, height, SECTION)

	box(inner, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 0, 2), ACCENT)

	local square = box(inner, UDim2.fromOffset(7, 9), UDim2.fromOffset(150, 130), WHITE, BLACK)

	local saturationLayer = box(square, UDim2.new(), UDim2.fromScale(1, 1), WHITE)

	create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = saturationLayer })

	local brightnessLayer = box(square, UDim2.new(), UDim2.fromScale(1, 1), BLACK)

	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = brightnessLayer })

	local squareCursor = box(square, UDim2.new(), UDim2.fromOffset(4, 4), WHITE, BLACK)

	local squareHit = hitbox(square, UDim2.new(), UDim2.fromScale(1, 1))

	local hueBar = box(inner, UDim2.fromOffset(164, 9), UDim2.fromOffset(14, 130), WHITE, BLACK)

	create("UIGradient", { Color = RAINBOW, Rotation = 90, Parent = hueBar })

	local hueCursor = box(hueBar, UDim2.new(), UDim2.new(1, 2, 0, 2), WHITE, BLACK)

	local hueHit = hitbox(hueBar, UDim2.new(), UDim2.fromScale(1, 1))

	local _, hexInner = well(inner, UDim2.fromOffset(7, 147), UDim2.new(1, -14, 0, 18), FIELD)

	local hexBox = textObject("TextBox", hexInner, "", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0))

	hexBox.ClearTextOnFocus = false

	local function refresh()

		local color = Color3.fromHSV(hue, saturation, brightness)

		square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)

		squareCursor.Position = UDim2.new(saturation, -2, 1 - brightness, -2)

		hueCursor.Position = UDim2.new(0, -1, hue, -1)

		hexBox.Text = "#" .. string.upper(color:ToHex())

		onChange(color)

	end

	bindDrag(squareHit, function(position)

		saturation = math.clamp((position.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)

		brightness = 1 - math.clamp((position.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)

		refresh()

	end)

	bindDrag(hueHit, function(position)

		hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)

		refresh()

	end)

	hexBox.FocusLost:Connect(function()

		local hex = string.gsub(hexBox.Text, "^#", "")
		local valid, color = pcall(Color3.fromHex, hex)

		if valid then

			hue, saturation, brightness = color:ToHSV()

		end

		refresh()

	end)

	refresh()

	placePopup(frame, anchor, width, height)

	activePopup = { Frame = frame, Anchor = anchor }

end

local function addRow(section, height)

	local row = panel(section.Frame, UDim2.fromOffset(7, section.Height), UDim2.new(1, -14, 0, height))

	section.Height = section.Height + height

	return row

end

local function buildBind(row, bind, onResize, isMenuKey)

	local mode = bind[1]

	local key = bind[2]

	local capturing = false

	local longPressed = false

	local bindState

	local outer, inner = well(row, UDim2.fromScale(1, 0), UDim2.fromOffset(0, 13), SECTION)

	outer.AnchorPoint = Vector2.new(1, 0)

	local keyLabel = textObject("TextLabel", inner, "", UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)

	local hit = hitbox(outer, UDim2.new(), UDim2.fromScale(1, 1))

	bindHover(hit, inner)

	local function refresh()

		local text = mode .. ": " .. (capturing and "..." or key)

		local width = textWidth(text, TEXT_SIZE) + 6

		keyLabel.Text = text

		outer.Size = UDim2.fromOffset(width, 13)

		if bindState then
			bindState.Value = key
			bindState.Mode = mode
		end

		onResize(width + 1)

	end

	local function finishCapture(name)

		capturing = false

		activeCapture = nil

		if name == "Backspace" then

			if not isMenuKey then

				key = "None"

			end

		elseif name and name ~= "Escape" and not (isMenuKey and string.sub(name, 1, 5) == "Mouse") then

			key = name

			if isMenuKey then

				menuKey = name

			end

		end

		refresh()

	end

	local function startCapture()

		closePopup()

		capturing = true

		activeCapture = { Anchor = outer, Finish = finishCapture }

		refresh()

	end

	local function toggleModes()

		if isPopupAnchor(outer) then

			closePopup()

			return

		end

		local widest = 0

		for _, option in ipairs(BIND_MODES) do

			widest = math.max(widest, textWidth(option, scaledTextSize(BIND_MENU_TEXT)))

		end

		openList(outer, BIND_MODES, function(option)

			return option == mode

		end, function(option)

			mode = option

			refresh()

			closePopup()

		end, {

			Width = widest + 12,

			RowHeight = BIND_MENU_ROW,

			TextSize = BIND_MENU_TEXT,

			AlignRight = true,

		})

	end

	hit.InputBegan:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.Touch then

			longPressed = false

		end

	end)

	hit.Activated:Connect(function(input)

		if longPressed then

			longPressed = false

		elseif capturing then

			finishCapture(input.UserInputType == Enum.UserInputType.MouseButton1 and "MouseButton1" or nil)

		else

			startCapture()

		end

	end)

	hit.MouseButton2Click:Connect(function()

		if capturing then

			finishCapture("MouseButton2")

		elseif not isMenuKey then

			toggleModes()

		end

	end)

	if not isMenuKey then

		hit.TouchLongPress:Connect(function(_, state)

			if state == Enum.UserInputState.Begin and not capturing then

				longPressed = true

				toggleModes()

			end

		end)

	end

	bindState = {
		Type = "KeyPicker",
		Value = key,
		Mode = mode,
	}
	function bindState:SetValue(value)
		if type(value) == "table" then
			key = tostring(value[1] or "None")
			mode = tostring(value[2] or mode)
		elseif type(value) == "string" then
			key = value
		end
		if isMenuKey then
			menuKey = key
		end
		self.Value = key
		self.Mode = mode
		refresh()
	end
	registerConfigObject(bindState, false)

	refresh()

end

local function buildSwatches(row, colors, onChange)

	local count = #colors

	for index, initial in ipairs(colors) do

		local color = initial

		local offset = (count - index) * SWATCH_PITCH + SWATCH_WIDTH

		local outer, inner = well(row, UDim2.new(1, -offset, 0, 0), UDim2.fromOffset(SWATCH_WIDTH, 13), color)

		local colorState = {
			Type = "ColorPicker",
			Value = color,
			Transparency = 0,
		}
		function colorState:SetValueRGB(value, transparency)
			color = value
			self.Value = value
			self.Transparency = transparency or 0
			outer.BackgroundColor3 = value
			inner.BackgroundColor3 = value
			if onChange then
				onChange(value)
			end
		end
		registerConfigObject(colorState, false)

		local shine = box(inner, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), WHITE)

		shine.BackgroundTransparency = 0.92

		create("UIGradient", { Color = ColorSequence.new(WHITE, BLACK), Rotation = 90, Parent = shine })

		local hit = hitbox(row, UDim2.new(1, -offset, 0, 0), UDim2.fromOffset(SWATCH_WIDTH, 13))

		bindHover(hit, inner)

		hit.Activated:Connect(function()

			if isPopupAnchor(outer) then

				closePopup()

				return

			end

			openPicker(outer, color, function(value)

				colorState:SetValueRGB(value)

			end)

		end)

	end

	return (count - 1) * SWATCH_PITCH + SWATCH_WIDTH + 1

end

local Builders = {}

function Builders.Toggle(section, spec)

	local row = addRow(section, ROW_TOGGLE)

	local outer, inner = well(row, UDim2.new(), UDim2.fromOffset(13, 13), CONTROL)

	shade(inner, SHADE_CONTROL)

	local fill = accentFill(outer, UDim2.fromScale(1, 1))

	local enabled = spec.Enabled

	fill.Visible = enabled

	local toggleState = { Type = "Toggle", Value = enabled == true }
	function toggleState:SetValue(value, notify)
		enabled = value == true
		self.Value = enabled
		fill.Visible = enabled
		if notify ~= false then
			safeCallback(spec.Callback, enabled)
		end
	end
	spec.State = toggleState
	if not spec.IgnoreConfig then
		registerConfigObject(toggleState, true, spec.ConfigKey)
	end

	local label = clippedText(row, spec.Text, UDim2.fromOffset(LABEL_OFFSET, 0), UDim2.new(1, -LABEL_OFFSET, 0, 14))

	local hit = hitbox(row, UDim2.new(), UDim2.new(1, 0, 0, 13))

	bindHover(hit, inner)

	local function reserve(width)

		label.Size = UDim2.new(1, -LABEL_OFFSET - width, 0, 14)

		hit.Size = UDim2.new(1, -width, 0, 13)

	end

	if spec.Bind then

		buildBind(row, spec.Bind, reserve, false)

	elseif spec.Colors then

		reserve(buildSwatches(row, spec.Colors))

	end

	hit.Activated:Connect(function()

		toggleState:SetValue(not enabled)

	end)

end

function Builders.Slider(section, spec)

	local row = addRow(section, ROW_SLIDER)

	local minimum = spec.Min

	local maximum = spec.Max

	local maximumText = tostring(maximum)

	textObject("TextLabel", row, spec.Text, UDim2.new(), UDim2.new(1, 0, 0, 13))

	local valueLabel = textObject("TextLabel", row, "", UDim2.new(), UDim2.new(1, -2, 0, 13), Enum.TextXAlignment.Right)

	local outer, inner = well(row, UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 10), CONTROL)

	shade(inner, SHADE_CONTROL)

	local fill = accentFill(outer, UDim2.fromScale(0, 1))

	local hit = hitbox(row, UDim2.fromOffset(0, 11), UDim2.new(1, 0, 0, 16))

	local current = spec.Value
	local sliderState = { Type = "Slider", Value = current }
	local function setValue(value, notify)

		value = tonumber(value) or minimum
		current = math.clamp(roundTo(value, spec.Decimals), minimum, maximum)
		sliderState.Value = current

		local alpha = (current - minimum) / (maximum - minimum)

		fill.Size = UDim2.new(alpha, 2 - 2 * alpha, 1, 0)

		fill.Visible = alpha > 0

		valueLabel.Text = tostring(current) .. "/" .. maximumText

		if notify ~= false then
			safeCallback(spec.Callback, current)
		end

	end

	bindDrag(hit, function(position)

		local alpha = math.clamp((position.X - outer.AbsolutePosition.X) / outer.AbsoluteSize.X, 0, 1)

		setValue(minimum + (maximum - minimum) * alpha, true)

	end, function()

		closePopup()

		section.Column.ScrollingEnabled = false

	end, function()

		section.Column.ScrollingEnabled = true

	end)

	bindHover(hit, inner)

	function sliderState:SetValue(value)
		setValue(value, true)
	end
	registerConfigObject(sliderState, false, spec.ConfigKey)

	setValue(spec.Value, false)

end

function Builders.Caption(section, spec)

	local row = addRow(section, ROW_TOGGLE)

	textObject("TextLabel", row, spec.Text, UDim2.new(), UDim2.new(1, 0, 0, 14))

end

function Builders.Dropdown(section, spec)

	local row = addRow(section, ROW_FIELD)

	local outer, inner = well(row, UDim2.fromOffset(0, -1), UDim2.new(1, 0, 0, 18), FIELD)

	local valueLabel = textObject("TextLabel", inner, "", UDim2.fromOffset(5, 0), UDim2.new(1, -22, 1, 1))

	valueLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local icon = textObject("TextLabel", inner, "+", UDim2.fromOffset(0, -1), UDim2.new(1, -4, 1, 0), Enum.TextXAlignment.Right)

	local hit = hitbox(row, UDim2.fromOffset(0, -1), UDim2.new(1, 0, 0, 18))

	bindHover(hit, inner)

	local chosen = {}

	for _, option in ipairs(spec.Default or {}) do
		chosen[option] = true
	end

	local dropdownState

	local function currentValue()
		local names = {}
		for _, option in ipairs(spec.Options) do
			if chosen[option] then
				names[#names + 1] = option
			end
		end
		if spec.Multi then
			return names
		end
		return names[1]
	end

	local function refresh(notify)
		local names = {}
		for _, option in ipairs(spec.Options) do
			if chosen[option] then
				names[#names + 1] = option
			end
		end
		valueLabel.Text = #names > 0 and table.concat(names, ", ") or "None"
		if dropdownState then
			dropdownState.Value = currentValue()
			if notify == true then
				safeCallback(spec.Callback, dropdownState.Value)
			end
		end
	end

	local function setChosen(value, notify)
		table.clear(chosen)
		if type(value) == "table" then
			for _, option in ipairs(value) do
				chosen[option] = true
			end
		elseif value ~= nil and value ~= "" then
			chosen[value] = true
		end
		refresh(notify)
	end

	hit.Activated:Connect(function()

		if isPopupAnchor(outer) then

			closePopup()

			return

		end

		openList(outer, spec.Options, function(option)

			return chosen[option] == true

		end, function(option)

			if spec.Multi then

				chosen[option] = not chosen[option] and true or nil

				refresh(true)

			else

				setChosen(option, true)

				closePopup()

			end

		end, {

			Width = outer.AbsoluteSize.X / menuScale.Scale,

			OnClose = function()

				icon.Text = "+"

			end,

		})

		icon.Text = "-"

	end)

	dropdownState = {
		Type = "Dropdown",
		Value = currentValue(),
		Multi = spec.Multi == true,
	}
	function dropdownState:SetValue(value, notify)
		setChosen(value, notify ~= false)
	end
	spec.State = dropdownState
	if not spec.IgnoreConfig then
		registerConfigObject(dropdownState, false, spec.ConfigKey)
	end

	if spec.Options == configState.Items then
		table.insert(configState.Observers, function()
			local valid = {}
			for _, option in ipairs(spec.Options) do
				if chosen[option] then
					valid[option] = true
				end
			end
			table.clear(chosen)
			for option in pairs(valid) do
				chosen[option] = true
			end
			refresh(false)
		end)
	end

	refresh(false)

end

function Builders.Button(section, spec)

	local row = addRow(section, ROW_FIELD)

	local _, inner = well(row, UDim2.fromOffset(0, -1), UDim2.new(1, 0, 0, 18), FIELD)

	local hit = textObject(

		"TextButton",

		inner,

		spec.Text,

		UDim2.new(),

		UDim2.fromScale(1, 1),

		Enum.TextXAlignment.Center

	)

	hit.AutoButtonColor = false

	bindHover(hit, inner)

	hit.MouseButton1Down:Connect(function()

		inner.BackgroundColor3 = MAIN

	end)

	hit.MouseButton1Up:Connect(function()

		inner.BackgroundColor3 = FIELD

	end)

	hit.MouseLeave:Connect(function()

		inner.BackgroundColor3 = FIELD

	end)

	if spec.Action then

		hit.Activated:Connect(function()
			spec.Action(hit)
		end)

	end

end

function Builders.Field(section, spec)

    local row = addRow(section, ROW_FIELD)

    local _, inner = well(row, UDim2.fromOffset(0, -1), UDim2.new(1, 0, 0, 18), FIELD)

    local input = textObject("TextBox", inner, spec.Value or "", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 1, 0))

    input.ClearTextOnFocus = false
    input.ClipsDescendants = true
    input.PlaceholderText = spec.Placeholder or "Enter text"
    input.PlaceholderColor3 = GREY
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.TextEditable = true

    input:GetPropertyChangedSignal("Text"):Connect(function()
        spec.Value = input.Text
        if spec.ConfigNameField then
            configNameValue = input.Text
            configNameTextBox = input
        end
        safeCallback(spec.Callback, input.Text)
    end)

    if spec.ConfigNameField then
        configNameTextBox = input
        configNameValue = input.Text
    end

    spec.Input = input

end

function Builders.MenuKey(section, spec)

	local row = addRow(section, ROW_TOGGLE)

	local label = clippedText(row, spec.Text, UDim2.new(), UDim2.new(1, 0, 0, 13))

	buildBind(row, { spec.Mode or "Toggle", spec.Key }, function(width)

		label.Size = UDim2.new(1, -width, 0, 13)

	end, true)

end

function Builders.Color(section, spec)

	local row = addRow(section, ROW_TOGGLE)

	clippedText(row, spec.Text, UDim2.new(), UDim2.new(1, -(SWATCH_WIDTH + 8), 0, 14))

	buildSwatches(row, { spec.Value or ACCENT }, setAccentColor)

end

function Builders.ConfigList(section, spec)

	local height = spec.Height or 96

	local row = addRow(section, height)

	local _, inner = well(row, UDim2.fromOffset(0, -1), UDim2.new(1, 0, 0, height - 2), FIELD)

	local list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, #configState.Items * 18),
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Position = UDim2.fromOffset(1, 1),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.new(1, -2, 1, -2),
		Parent = inner,
	})

	local entries = {}

	local function refresh()
		for _, record in ipairs(entries) do
			local selected = record.Name == configState.Selected
			record.Button.TextColor3 = selected and SETTINGS_HIGHLIGHT or WHITE
			record.Button.BackgroundTransparency = 1
		end
	end

	local function rebuild()
		for _, record in ipairs(entries) do
			record.Button:Destroy()
		end
		table.clear(entries)
		list.CanvasSize = UDim2.fromOffset(0, #configState.Items * 18)

		for index, name in ipairs(configState.Items) do
			local entry = textObject(
				"TextButton",
				list,
				name,
				UDim2.fromOffset(4, (index - 1) * 18),
				UDim2.new(1, -8, 0, 18)
			)
			entry.AutoButtonColor = false
			setBaseTextSize(entry, spec.TextSize or 12)
			entry.TextXAlignment = Enum.TextXAlignment.Center
			entry.TextTruncate = Enum.TextTruncate.AtEnd
			entry.Activated:Connect(function()
				selectConfig(name)
			end)
			entries[index] = { Name = name, Button = entry }
		end
		refresh()
	end

	rebuild()
	table.insert(configState.Observers, function(itemsChanged)
		if itemsChanged then
			rebuild()
		else
			refresh()
		end
	end)
	table.insert(accentRefreshers, refresh)

end

local function buildSection(column, spec)

	local frame = box(column, UDim2.new(), UDim2.new(1, 1, 0, 0), SECTION, OUTLINE, true)

	box(frame, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2), SECTION, BLACK, true)

	box(frame, UDim2.fromOffset(2, 2), UDim2.new(1, -4, 0, 2), ACCENT)

	textObject("TextLabel", frame, spec.Title, UDim2.fromOffset(5, 4), UDim2.new(1, -10, 0, 18))

	local section = { Column = column, Frame = frame, Height = SECTION_HEADER }

	for _, row in ipairs(spec.Rows) do

		Builders[row.Kind](section, row)

	end

	frame.Size = UDim2.new(1, 1, 0, section.Height + 1)

	return section

end

local function buildColumn(host, position, sections)

	local column = create("ScrollingFrame", {

		BackgroundTransparency = 1,

		BorderSizePixel = 0,

		ElasticBehavior = Enum.ElasticBehavior.Never,

		Position = position,

		ScrollBarThickness = 0,

		ScrollingDirection = Enum.ScrollingDirection.Y,

		Size = UDim2.new(0.5, -10, 1, -11),

		Parent = host,

	})

	local offset = 0

	for _, spec in ipairs(sections) do

		local section = buildSection(column, spec)

		section.Frame.Position = UDim2.fromOffset(0, offset)

		offset = offset + section.Height + 1 + SECTION_GAP

	end

	column.CanvasSize = UDim2.fromOffset(0, math.max(offset - SECTION_GAP, 0))

	column:GetPropertyChangedSignal("CanvasPosition"):Connect(closePopup)

end

local function buildTabs(host, pages, renderPage)

	local count = #pages

	local strip = panel(host, UDim2.fromOffset(6, 7), UDim2.new(1, -12, 0, 21))

	strip.ZIndex = 2

	local _, container = well(host, UDim2.fromOffset(6, 27), UDim2.new(1, -12, 1, -33), MAIN)

	local tabs = {}

	local function select(selected)

		closePopup()

		for index, tab in ipairs(tabs) do

			local active = index == selected

			tab.Face.BackgroundColor3 = active and MAIN or BACKGROUND

			tab.Blocker.Visible = active

			tab.Content.Visible = active

		end

	end

	for index, page in ipairs(pages) do

		local slot = panel(

			strip,

			UDim2.new((index - 1) / count, index - 1, 0, 0),

			UDim2.new(1 / count, index == count and -3 or -5, 1, 0)

		)

		box(slot, UDim2.fromOffset(-1, -1), UDim2.new(1, 2, 1, 0), BLACK)

		local face = box(slot, UDim2.new(), UDim2.fromScale(1, 1), BACKGROUND, OUTLINE, true)

		local blocker = box(slot, UDim2.new(0, 1, 1, -1), UDim2.new(1, -2, 0, 1), MAIN)

		local button = textObject(

			"TextButton",

			slot,

			page.Name,

			UDim2.fromOffset(0, -1),

			UDim2.new(1, 0, 1, 1),

			Enum.TextXAlignment.Center

		)

		button.AutoButtonColor = false

		button.Activated:Connect(function()

			select(index)

		end)

		local content = panel(container, UDim2.new(), UDim2.fromScale(1, 1))

		tabs[index] = { Face = face, Blocker = blocker, Content = content }

		renderPage(content, page)

	end

	select(1)

end

local function renderPage(host, page)

	if page.Pages then

		buildTabs(host, page.Pages, renderPage)

	else

		buildColumn(host, UDim2.fromOffset(6, 5), page.Left)

		buildColumn(host, UDim2.new(0.5, 3, 0, 5), page.Right)

	end

end

local mobileBox, mobileBoxInner = well(

	screen,

	UDim2.fromOffset(FIT_MARGIN, FIT_MARGIN),

	UDim2.fromOffset(MOBILE_BOX_WIDTH, MOBILE_BOX_HEIGHT),

	MAIN

)

mobileBox.Visible = UserInputService.TouchEnabled

mobileBox.ZIndex = 5

box(mobileBoxInner, UDim2.fromOffset(1, 1), UDim2.new(1, -2, 0, 2), ACCENT)

local mobileButton = textObject(

	"TextButton",

	mobileBoxInner,

	"Close",

	UDim2.new(),

	UDim2.fromScale(1, 1),

	Enum.TextXAlignment.Center

)

mobileButton.AutoButtonColor = false

local function setMenuVisible(visible)

	closePopup()

	window.Visible = visible

	mobileButton.Text = visible and "Close" or "Open"

end

local mobileBoxStart

local mobileBoxOrigin

local mobileBoxDragged = false

bindDrag(mobileButton, function(position)

	local delta = position - mobileBoxOrigin

	if delta.Magnitude > TAP_SLOP then

		mobileBoxDragged = true

	end

	if mobileBoxDragged then

		local limit = screen.AbsoluteSize

		mobileBox.Position = UDim2.fromOffset(

			math.clamp(mobileBoxStart.X.Offset + delta.X, 0, math.max(0, limit.X - MOBILE_BOX_WIDTH)),

			math.clamp(mobileBoxStart.Y.Offset + delta.Y, 0, math.max(0, limit.Y - MOBILE_BOX_HEIGHT))

		)

	end

end, function(input)

	mobileBoxDragged = false

	mobileBoxStart = mobileBox.Position

	mobileBoxOrigin = input.Position

end)

mobileButton.Activated:Connect(function()

	if not mobileBoxDragged then

		setMenuVisible(not window.Visible)

	end

end)

local dragHandle = hitbox(chrome, UDim2.new(), UDim2.new(1, 0, 0, 19))

dragHandle.Modal = true

local dragStart

local dragOrigin

bindDrag(dragHandle, function(position)

	local delta = position - dragOrigin

	window.Position = UDim2.new(

		dragStart.X.Scale,

		dragStart.X.Offset + delta.X,

		dragStart.Y.Scale,

		dragStart.Y.Offset + delta.Y

	)

	keepWindowOnScreen()

end, function(input)

	closePopup()

	dragStart = window.Position

	dragOrigin = input.Position

end)

local resizeStart

local resizeOrigin

local function addResizeHandle(position, size, horizontal, vertical)

	local handle = hitbox(window, position, size)

	handle.ZIndex = 3

	bindDrag(handle, function(pointer)

		local growthX = (pointer.X - resizeOrigin.X) * horizontal * 2 / WINDOW_WIDTH

		local growthY = (pointer.Y - resizeOrigin.Y) * vertical * 2 / WINDOW_HEIGHT

		local growth = growthX

		if horizontal == 0 then

			growth = growthY

		elseif vertical ~= 0 then

			growth = math.max(growthX, growthY)

		end

		customScale = resizeStart + growth

		applyScale()

	end, function(input)

		closePopup()

		resizeStart = menuScale.Scale

		resizeOrigin = input.Position

	end)

end

local edgeThickness = RESIZE_OUTSIDE + RESIZE_INSIDE

local cornerSize = UDim2.fromOffset(edgeThickness, edgeThickness)

local sideLength = -2 * RESIZE_INSIDE

addResizeHandle(

	UDim2.fromOffset(-RESIZE_OUTSIDE, RESIZE_INSIDE),

	UDim2.new(0, edgeThickness, 1, sideLength),

	-1,

	0

)

addResizeHandle(

	UDim2.new(1, -RESIZE_INSIDE, 0, RESIZE_INSIDE),

	UDim2.new(0, edgeThickness, 1, sideLength),

	1,

	0

)

addResizeHandle(

	UDim2.fromOffset(RESIZE_INSIDE, -RESIZE_OUTSIDE),

	UDim2.new(1, sideLength, 0, RESIZE_OUTSIDE + RESIZE_TOP_INSIDE),

	0,

	-1

)

addResizeHandle(

	UDim2.new(0, RESIZE_INSIDE, 1, -RESIZE_INSIDE),

	UDim2.new(1, sideLength, 0, edgeThickness),

	0,

	1

)

addResizeHandle(UDim2.fromOffset(-RESIZE_OUTSIDE, -RESIZE_OUTSIDE), cornerSize, -1, -1)

addResizeHandle(UDim2.new(1, -RESIZE_INSIDE, 0, -RESIZE_OUTSIDE), cornerSize, 1, -1)

addResizeHandle(UDim2.new(0, -RESIZE_OUTSIDE, 1, -RESIZE_INSIDE), cornerSize, -1, 1)

addResizeHandle(UDim2.new(1, -RESIZE_INSIDE, 1, -RESIZE_INSIDE), cornerSize, 1, 1)

-- Callback signatures:
--   toggle("Enabled", false, callback)
--   toggle("Enabled", false, tinted(WHITE), callback)
--   slider("Speed", 1, 0, 5, 2, callback)
--   dropdown({ "A", "B" }, { "A" }, false, callback)
-- Callbacks receive the updated value. Initial UI construction is silent.
local function toggle(text, enabled, options, callback)

	if type(options) == "function" and callback == nil then
		callback = options
		options = nil
	end

	local row = options or {}

	row.Kind = "Toggle"

	row.Text = text

	row.Enabled = enabled

	row.Callback = callback or row.Callback

	return row

end

local function slider(text, value, minimum, maximum, decimals, callback)

	return {
		Kind = "Slider",
		Text = text,
		Value = value,
		Min = minimum,
		Max = maximum,
		Decimals = decimals,
		Callback = callback,
	}

end

local function caption(text)

	return { Kind = "Caption", Text = text }

end

local function dropdown(options, default, multi, callback)

	return { Kind = "Dropdown", Options = options, Default = default, Multi = multi, Callback = callback }

end

local function button(text, action)

	return { Kind = "Button", Text = text, Action = action }

end

local function field(placeholder, options)

	local spec = options or {}
	spec.Kind = "Field"
	spec.Placeholder = placeholder
	return spec

end

local function menuKeyRow(text, key, mode)

	return { Kind = "MenuKey", Text = text, Key = key, Mode = mode }

end

local function colorRow(text, value)

	return { Kind = "Color", Text = text, Value = value }

end

local function configList()

	return { Kind = "ConfigList", Height = 96, TextSize = 12 }

end

local function bindable(mode, key)

	return { Bind = { mode, key } }

end

local function tinted(...)

	return { Colors = { ... } }

end

-- Autoload settings are stored separately from ordinary configs so loading a
-- config cannot silently replace the user's startup choice.
local function configExistsOnDisk(name)
	if not SaveManager or type(isfile) ~= "function" then
		return false
	end

	local bareName = stripJsonExtension(name)
	if bareName == "" or bareName:find("/", 1, true) or bareName:find("\\", 1, true) then
		return false
	end

	local path = SaveManager.Folder .. "/settings/" .. bareName .. ".json"
	local ok, exists = pcall(isfile, path)
	return ok and exists == true
end

local function writeAutoLoadEnabled(enabled)
	if not SaveManager or type(writefile) ~= "function" then
		return
	end

	local path = SaveManager.Folder .. "/settings/autoload-enabled.txt"
	local ok, err = pcall(writefile, path, enabled and "true" or "false")
	if not ok then
		warn("[KiciaUI] Could not save Auto Load Config setting: " .. tostring(err))
	end
end

local function writeAutoLoadConfig(value)
	if not SaveManager or type(writefile) ~= "function" then
		return
	end

	if type(value) == "table" then
		value = value[1]
	end

	local bareName = stripJsonExtension(value)
	if bareName == "" or not configExistsOnDisk(bareName) then
		warn("[KiciaUI] Select an existing config before setting it to auto load.")
		return
	end

	-- Linoria's LoadAutoloadConfig reads a bare config name (without .json).
	local path = SaveManager.Folder .. "/settings/autoload.txt"
	local ok, err = pcall(writefile, path, bareName)
	if not ok then
		warn("[KiciaUI] Could not save autoload config: " .. tostring(err))
	end
end

local autoLoadToggle = toggle("Auto Load Config", true, writeAutoLoadEnabled)
autoLoadToggle.IgnoreConfig = true

local autoLoadDropdown = dropdown(
	configState.Items,
	{ "default.json" },
	false,
	writeAutoLoadConfig
)
autoLoadDropdown.IgnoreConfig = true

local function espRows(states)

	return {

		toggle("Enabled", states[1]),

		toggle("Bounding Box", states[2], tinted(WHITE, BLACK)),

		dropdown({ "Full", "Corners", "3D" }, { "Full" }),

		toggle("Name", states[3], tinted(WHITE, BLACK)),

		toggle("Health Bar", states[4], tinted(GREEN, RED, BLACK)),

		toggle("Weapon Text", states[5], tinted(WHITE, BLACK)),

		toggle("Ammo", states[6], tinted(WHITE, BLACK)),

		toggle("Distance", states[7], tinted(WHITE, BLACK)),

		toggle("Katana Status", states[8], tinted(RED, BLACK)),

		toggle("Chams", states[9], tinted(WHITE, GREY)),

		toggle("Chams Behind Walls", states[10], tinted(PALE_YELLOW, GOLD)),

	}

end

local ALL_OFF = { false, false, false, false, false, false, false, false, false, false }

local ENEMY_DEFAULTS = { true, true, true, true, true, false, true, true, false, false }

-- A local mock overlay used only to test Visuals controls and config persistence.
-- It never reads players/characters and never draws over gameplay entities.
local visualPreviewState = {
    Enabled = false,
    Box = true,
    Name = true,
    Health = true,
    Distance = true,
    BoxStyle = "Full",
    HealthPercent = 75,
}

local previewPanel = box(
    screen,
    UDim2.new(1, -14, 0, 14),
    UDim2.fromOffset(216, 164),
    MAIN,
    ACCENT,
    true
)
previewPanel.AnchorPoint = Vector2.new(1, 0)
previewPanel.Visible = false
previewPanel.ZIndex = 20

local previewHeader = box(
    previewPanel,
    UDim2.fromOffset(1, 1),
    UDim2.new(1, -2, 0, 20),
    SECTION,
    OUTLINE,
    true
)
previewHeader.ZIndex = 21

local previewTitle = textObject(
    "TextLabel",
    previewPanel,
    "VISUAL PREVIEW  /  UI TEST",
    UDim2.fromOffset(8, 3),
    UDim2.new(1, -16, 0, 16)
)
previewTitle.ZIndex = 22
setBaseTextSize(previewTitle, 9)

local previewName = textObject(
    "TextLabel",
    previewPanel,
    "Training Dummy",
    UDim2.fromOffset(42, 25),
    UDim2.fromOffset(132, 15),
    Enum.TextXAlignment.Center
)
previewName.ZIndex = 22
setBaseTextSize(previewName, 10)

local previewBox = create("Frame", {
    BackgroundTransparency = 1,
    BorderColor3 = GREEN,
    BorderSizePixel = 1,
    Position = UDim2.fromOffset(82, 45),
    Size = UDim2.fromOffset(54, 66),
    ZIndex = 21,
    Parent = previewPanel,
})

local previewDepthBox = create("Frame", {
    BackgroundTransparency = 1,
    BorderColor3 = CYAN,
    BorderSizePixel = 1,
    Position = UDim2.fromOffset(88, 40),
    Size = UDim2.fromOffset(54, 66),
    ZIndex = 20,
    Parent = previewPanel,
})

local previewCorners = {}
local cornerParts = {
    { 80, 45, 11, 2 }, { 80, 45, 2, 11 },
    { 127, 45, 11, 2 }, { 136, 45, 2, 11 },
    { 80, 109, 11, 2 }, { 80, 100, 2, 11 },
    { 127, 109, 11, 2 }, { 136, 100, 2, 11 },
}
for _, values in ipairs(cornerParts) do
    local part = box(
        previewPanel,
        UDim2.fromOffset(values[1], values[2]),
        UDim2.fromOffset(values[3], values[4]),
        GREEN
    )
    part.ZIndex = 22
    table.insert(previewCorners, part)
end

local previewHealthTrack = box(
    previewPanel,
    UDim2.fromOffset(70, 46),
    UDim2.fromOffset(6, 65),
    RED,
    OUTLINE,
    true
)
previewHealthTrack.ZIndex = 21

local previewHealthFill = box(
    previewHealthTrack,
    UDim2.new(0, 1, 1, -1),
    UDim2.new(1, -2, 0, 45),
    GREEN
)
previewHealthFill.AnchorPoint = Vector2.new(0, 1)
previewHealthFill.ZIndex = 22

local previewHealthLabel = textObject(
    "TextLabel",
    previewPanel,
    "75 HP",
    UDim2.fromOffset(145, 55),
    UDim2.fromOffset(58, 14)
)
previewHealthLabel.ZIndex = 22
setBaseTextSize(previewHealthLabel, 10)

local previewDistance = textObject(
    "TextLabel",
    previewPanel,
    "15m",
    UDim2.fromOffset(82, 115),
    UDim2.fromOffset(54, 14),
    Enum.TextXAlignment.Center
)
previewDistance.ZIndex = 22
setBaseTextSize(previewDistance, 10)

local previewFooter = textObject(
    "TextLabel",
    previewPanel,
    "DEMO ONLY - NO GAMEPLAY EFFECT",
    UDim2.fromOffset(7, 144),
    UDim2.new(1, -14, 0, 13),
    Enum.TextXAlignment.Center
)
previewFooter.ZIndex = 22
previewFooter.TextColor3 = GREY
setBaseTextSize(previewFooter, 8)

local function updateVisualPreview()
    previewPanel.Visible = visualPreviewState.Enabled == true
    previewName.Visible = visualPreviewState.Name == true
    previewHealthTrack.Visible = visualPreviewState.Health == true
    previewHealthLabel.Visible = visualPreviewState.Health == true
    previewDistance.Visible = visualPreviewState.Distance == true

    local showBox = visualPreviewState.Box == true
    local style = visualPreviewState.BoxStyle
    previewBox.Visible = showBox and style ~= "Corners"
    previewDepthBox.Visible = showBox and style == "3D"
    for _, part in ipairs(previewCorners) do
        part.Visible = showBox and style == "Corners"
    end

    local percent = math.clamp(tonumber(visualPreviewState.HealthPercent) or 75, 0, 100)
    previewHealthFill.Size = UDim2.new(1, -2, 0, math.floor(60 * percent / 100))
    previewHealthLabel.Text = tostring(math.floor(percent + 0.5)) .. " HP"
    previewHealthFill.BackgroundColor3 = percent <= 25 and RED or (percent <= 55 and PALE_YELLOW or GREEN)
end

local previewEnabledRow = toggle("Enable Demo Preview", false, function(value)
    visualPreviewState.Enabled = value
    updateVisualPreview()
end)
previewEnabledRow.ConfigKey = "VisualPreviewEnabled"

local previewBoxRow = toggle("Preview Box", true, function(value)
    visualPreviewState.Box = value
    updateVisualPreview()
end)
previewBoxRow.ConfigKey = "VisualPreviewBox"

local previewBoxStyleRow = dropdown({ "Full", "Corners", "3D" }, { "Full" }, false, function(value)
    visualPreviewState.BoxStyle = type(value) == "table" and value[1] or value or "Full"
    updateVisualPreview()
end)
previewBoxStyleRow.ConfigKey = "VisualPreviewBoxStyle"

local previewNameRow = toggle("Preview Name", true, function(value)
    visualPreviewState.Name = value
    updateVisualPreview()
end)
previewNameRow.ConfigKey = "VisualPreviewName"

local previewHealthRow = toggle("Preview Health Bar", true, function(value)
    visualPreviewState.Health = value
    updateVisualPreview()
end)
previewHealthRow.ConfigKey = "VisualPreviewHealth"

local previewDistanceRow = toggle("Preview Distance", true, function(value)
    visualPreviewState.Distance = value
    updateVisualPreview()
end)
previewDistanceRow.ConfigKey = "VisualPreviewDistance"

local previewHealthPercentRow = slider("Preview Health", 75, 0, 100, 0, function(value)
    visualPreviewState.HealthPercent = value
    updateVisualPreview()
end)
previewHealthPercentRow.ConfigKey = "VisualPreviewHealthPercent"

local visualPreviewRows = {
    previewEnabledRow,
    previewBoxRow,
    previewBoxStyleRow,
    previewNameRow,
    previewHealthRow,
    previewDistanceRow,
    previewHealthPercentRow,
}

local HITPARTS = { "Head", "Torso", "Arms", "Legs" }

local Menu = {

	{

		Name = "Combat",

		Pages = {

			{

				Name = "Legitbot",

				Left = {

					{

						Title = "Main Settings",

						Rows = {

							toggle("Enabled", true, bindable("Toggle", "ButtonL3")),

							slider("Speed", 0.84, 0.1, 5, 2),

							slider("Speed (in attack)", 2, 0.1, 5, 2),

							slider("Speed scale - FOV", 100, 0, 100, 0),

							slider("Maximum lock-on time", 3, 0.5, 10, 1),

							slider("Reaction time (ms)", 100, 0, 500, 0),

							toggle("Team Check", true),

							toggle("Visible Check", false),

							caption("Targeting Hitparts"),

							dropdown(HITPARTS, { "Head" }, true),

						},

					},

				},

				Right = {

					{

						Title = "FOV Settings",

						Rows = {

							slider("Maximum FOV", 120, 0, 600, 0),

							toggle("Draw FOV", false, tinted(CYAN)),

							toggle("Dynamic FOV", false),

						},

					},

				},

			},

			{

				Name = "Silent Aim",

				Left = {

					{

						Title = "Main Settings",

						Rows = {

							toggle("Enabled", false, bindable("Always", "None")),

							slider("Hit Chance", 100, 0, 100, 0),

							toggle("Team Check", true),

							toggle("Visible Check", false),

							caption("Targeting Hitparts"),

							dropdown(HITPARTS, { "Head" }, true),

						},

					},

				},

				Right = {

					{

						Title = "FOV Settings",

						Rows = {

							slider("Maximum FOV", 120, 0, 600, 0),

							toggle("Draw FOV", false, tinted(CYAN)),

							toggle("Dynamic FOV", false),

						},

					},

				},

			},

			{

				Name = "Triggerbot",

				Left = {

					{

						Title = "Main",

						Rows = {

							toggle("Enabled", true, bindable("Always", "None")),

							slider("Delay (ms)", 0, 0, 500, 0),

							slider("Grace (ms)", 0, 0, 500, 0),

						},

					},

					{

						Title = "Targeting",

						Rows = {

							toggle("Visible Check", true),

							dropdown({ "Head", "Torso", "Random" }, { "Head" }),

						},

					},

				},

				Right = {

					{

						Title = "Advanced",

						Rows = {

							toggle("Random Delay", false),

							slider("Min Delay", 40, 0, 300, 0),

							slider("Max Delay", 120, 50, 500, 0),

						},

					},

				},

			},

			{

				Name = "Rage",

				Left = {

					{

						Title = "Main",

						Rows = {

							toggle("Enabled", false),

							slider("Field Of View (°)", 181, 0, 360, 0),

							toggle("Orbit Aura", false),

							toggle("Orbit Resolver", true),

							toggle("Orbit Anti Riot", false),

							toggle("Orbit Strike On Melee", false),

							slider("Orbit TP Delay", 1.3, 1, 5, 1),

							slider("Orbit Shot Interval", 0.4, 0, 2, 1),

						},

					},

				},

				Right = {

					{

						Title = "Anti Aim",

						Rows = {

							toggle("Enabled", false),

							caption("Pitch"),

							dropdown({ "Down", "Up", "Zero", "Random" }, { "Down" }),

							caption("Yaw Base"),

							dropdown({ "At Targets", "Camera", "Static" }, { "At Targets" }),

							caption("Yaw"),

							dropdown({ "Stutter Spin", "Spin", "Jitter", "Static" }, { "Stutter Spin" }),

							slider("Yaw Angle (°)", 0, -180, 180, 0),

							caption("Roll"),

							dropdown({ "Random", "None", "Left", "Right" }, { "Random" }),

							toggle("Jitter", false),

						},

					},

				},

			},

		},

	},

	{

		Name = "Visuals",

		Pages = {

			{

				Name = "ESP",

				Left = {

					{

						Title = "Main",

						Rows = {

							toggle("Enabled", true),

							caption("Bounding Box Size"),

							dropdown({ "Static", "Dynamic" }, { "Static" }),

						},

					},

					{ Title = "Team ESP", Rows = espRows(ALL_OFF) },

					{ Title = "UI Preview (Test Only)", Rows = visualPreviewRows },

				},

				Right = {

					{ Title = "Enemy ESP", Rows = espRows(ENEMY_DEFAULTS) },

					{ Title = "Friend ESP", Rows = espRows(ALL_OFF) },

				},

			},

			{

				Name = "Overrides",

				Left = {

					{

						Title = "Viewmodel",

						Rows = {

							toggle("Enabled", false),

							slider("Offset X", 0, -10, 10, 1),

							slider("Offset Y", 0, -10, 10, 1),

							slider("Offset Z", 0, -10, 10, 1),

							slider("Field Of View", 70, 30, 120, 0),

						},

					},

				},

				Right = {

					{

						Title = "Weapon",

						Rows = {

							toggle("Weapon Chams", false, tinted(WHITE, GREY)),

							caption("Weapon Material"),

							dropdown(MATERIALS, { "ForceField" }),

							slider("Transparency", 0, 0, 100, 0),

						},

					},

					{

						Title = "Arms",

						Rows = {

							toggle("Arm Chams", false, tinted(WHITE, GREY)),

							caption("Arm Material"),

							dropdown(MATERIALS, { "ForceField" }),

						},

					},

				},

			},

			{

				Name = "World",

				Left = {

					{

						Title = "Lighting",

						Rows = {

							toggle("Ambient", false, tinted(WHITE)),

							toggle("Color Shift", false, tinted(WHITE, BLACK)),

							slider("Brightness", 2, 0, 10, 1),

							slider("Clock Time", 14, 0, 24, 1),

							toggle("No Shadows", false),

						},

					},

				},

				Right = {

					{

						Title = "Atmosphere",

						Rows = {

							toggle("Fog", false, tinted(GREY)),

							slider("Fog Start", 0, 0, 1000, 0),

							slider("Fog End", 1000, 0, 5000, 0),

							caption("Skybox"),

							dropdown({ "Default", "Night", "Sunset", "Space" }, { "Default" }),

						},

					},

				},

			},

			{

				Name = "Player",

				Left = {

					{

						Title = "Local Player",

						Rows = {

							toggle("Self Chams", false, tinted(CYAN, GREY)),

							caption("Material"),

							dropdown(MATERIALS, { "ForceField" }),

							toggle("Hide Accessories", false),

							toggle("Trail", false, tinted(CYAN)),

						},

					},

				},

				Right = {

					{

						Title = "Camera",

						Rows = {

							slider("Field Of View", 70, 30, 120, 0),

							toggle("Third Person", false, bindable("Toggle", "None")),

							slider("", 12, 2, 40, 0),

							toggle("No Camera Shake", false),

						},

					},

				},

			},

		},

	},

	{

		Name = "Misc",

		Left = {

			{

				Title = "Movement",

				Rows = {

					toggle("Bunny Hop", false, bindable("Always", "None")),

					toggle("Auto Slide Jump", false),

					toggle("Jump Bug", false, bindable("Hold", "X")),

					toggle("Edge Jump", false, bindable("Always", "V")),

					toggle("Auto Strafe", false),

					caption("Auto Strafe Pattern"),

					dropdown({ "Adaptive", "Forward", "Sideways" }, { "Adaptive" }),

					slider("Auto Strafe Intensity", 80, 0, 100, 0),

					toggle("Auto View Angle", false),

				},

			},

			{

				Title = "Character",

				Rows = {

					toggle("Enable Walk Speed", false, bindable("Always", "None")),

					slider("", 45, 0, 150, 0),

					toggle("Enable Slide Boost", false, bindable("Always", "None")),

					slider("", 5, 1, 10, 0),

					toggle("Enable Jump Power", false, bindable("Always", "None")),

					slider("", 100, 0, 150, 0),

					toggle("Enable Fly", false, bindable("Always", "None")), --asdasd

					slider("", 50, 0, 10000, 0),

				},

			},

		},

		Right = {

			{

				Title = "Weapons",

				Rows = {

					toggle("Unlock All", true),

					toggle("Recoil Modifier (%)", false),

					slider("", 100, 0, 100, 0),

					toggle("No Spread", true),

					toggle("Rapid Fire", false),

					toggle("Automatic Weapon", false),

					toggle("Instant Scope", false),

					toggle("Always Backstab", true),

					toggle("Anti Katana", true),

				},

			},

			{

				Title = "World",

				Rows = {

					toggle("Prevent Out Of Bounds", false),

					toggle("Remove Killers", false),

					toggle("No Fire Damage", false),

				},

			},

		},

	},

	{

		Name = "Settings",

		Left = {

			{

				Title = "Discord",

				Rows = {

					button("Join Discord"),

					button("Copy Discord Invite"),

				},

			},

			{

				Title = "Menu",

				Rows = {

					menuKeyRow("Keybind", "RightShift", "Tap"),

					colorRow("Accent", SETTINGS_HIGHLIGHT),

					caption("Font"),

					dropdown({ "Ubuntu", "Gotham", "Arial", "Roboto", "Code", "SourceSans" }, { "Ubuntu" }, false, setFont),

					slider("Text Size", DEFAULT_TEXT_SIZE, 6, 26, 0, setTextSize),

					button("Unload", function()

						screen:Destroy()

					end),

					toggle("Debug Mode", false),

					toggle("Keybind Menu", false),

					toggle("Auto Reconnect", true),

					toggle("Auto Run Script", true),

					toggle("Silent Load", true),

					toggle("Disable 3D Rendering", false),

				},

			},

			{

				Title = "Server",

				Rows = {},

			},

		},

		Right = {

			{

				Title = "Configuration",

				Rows = {
                    field("Enter config name", {
                        Value = "",
                        ConfigNameField = true,
                    }),

                    button("Create", function()
                        createConfigEntry(configNameValue)
                    end),

					configList(),

					button("Load", function()
						local ok, err = callSaveManager("Load", stripJsonExtension(configState.Selected))
						if not ok then
							warn("[KiciaUI] Load failed: " .. tostring(err))
						end
					end),

					button("Save", function()
						saveConfigNamed(configState.Selected)
					end),

					button("Delete", function()
						deleteSelectedConfig()
					end),

					toggle("Auto Save To Config", true),

					dropdown(configState.Items, { "default.json" }),

					autoLoadToggle,

					autoLoadDropdown,

				},

			},

		},

	},

}

buildTabs(body, Menu, renderPage)
applyTypography(TEXT_SIZE)

if SaveManager then
    local hadDefault = false
    local ok, names = pcall(function()
        return SaveManager:RefreshConfigList()
    end)
    if ok then
        for _, name in ipairs(names) do
            if name == "default" then
                hadDefault = true
                break
            end
        end
    end
    if not hadDefault then
        local saved, err = callSaveManager("Save", "default")
        if not saved then
            warn("[KiciaUI] Could not create default config: " .. tostring(err))
        end
    end
    refreshConfigItems(configState.Selected or "default.json")

    -- Restore the selected autoload config. Linoria stores its name in
    -- settings/autoload.txt without the .json extension.
    local settingsFolder = SaveManager.Folder .. "/settings"
    local autoloadPath = settingsFolder .. "/autoload.txt"
    local autoloadEnabledPath = settingsFolder .. "/autoload-enabled.txt"

    local function readFileIfPresent(path)
        local existsOk, exists = pcall(isfile, path)
        if not existsOk or exists ~= true then
            return nil
        end
        local readOk, value = pcall(readfile, path)
        if not readOk then
            warn("[KiciaUI] Could not read " .. path .. ": " .. tostring(value))
            return nil
        end
        return tostring(value or "")
    end

    local autoLoadName
    local storedName = readFileIfPresent(autoloadPath)
    if storedName then
        storedName = storedName:gsub("^%s+", ""):gsub("%s+$", "")
        storedName = stripJsonExtension(storedName)
        if storedName ~= "" and configExistsOnDisk(storedName) then
            autoLoadName = storedName
        end
    end

    -- If the saved target was removed or never selected, use default (or the
    -- first real config available) as a safe startup fallback.
    if not autoLoadName then
        if configExistsOnDisk("default") then
            autoLoadName = "default"
        else
            for _, item in ipairs(configState.Items) do
                local candidate = stripJsonExtension(item)
                if configExistsOnDisk(candidate) then
                    autoLoadName = candidate
                    break
                end
            end
        end
    end

    if autoLoadName then
        if autoLoadDropdown.State then
            autoLoadDropdown.State:SetValue(autoLoadName .. ".json", false)
        end
        local writeOk, writeErr = pcall(writefile, autoloadPath, autoLoadName)
        if not writeOk then
            warn("[KiciaUI] Could not normalize autoload.txt: " .. tostring(writeErr))
        end
    end

    local autoLoadEnabled = true
    local storedEnabled = readFileIfPresent(autoloadEnabledPath)
    if storedEnabled ~= nil then
        autoLoadEnabled = storedEnabled:lower():match("^%s*true%s*$") ~= nil
    else
        local writeOk, writeErr = pcall(writefile, autoloadEnabledPath, "true")
        if not writeOk then
            warn("[KiciaUI] Could not initialize Auto Load Config setting: " .. tostring(writeErr))
        end
    end

    if autoLoadToggle.State then
        autoLoadToggle.State:SetValue(autoLoadEnabled, false)
    end

    -- Load only after every config-backed UI control has registered itself.
    if autoLoadEnabled and autoLoadName then
        local loadOk, loadErr = pcall(function()
            SaveManager:LoadAutoloadConfig()
        end)
        if not loadOk then
            warn("[KiciaUI] Auto-load failed: " .. tostring(loadErr))
        end
    end
end

table.insert(

	connections,

	UserInputService.InputBegan:Connect(function(input, processed)

		if activeCapture then

			local capture = activeCapture

			if not (isPointerPress(input) and isInside(capture.Anchor, input.Position)) then

				if isPress(input) then

					capture.Finish(nil)

				else

					local name = inputName(input)

					if name then

						capture.Finish(name)

					end

				end

			end

			return

		end

		if

			activePopup

			and isPointerPress(input)

			and not isInside(activePopup.Frame, input.Position)

			and not isInside(activePopup.Anchor, input.Position)

		then

			closePopup()

		end

		if not processed and inputName(input) == menuKey then

			setMenuVisible(not window.Visible)

		end

	end)

)

screen.Destroying:Connect(function()

	for _, connection in ipairs(connections) do

		connection:Disconnect()

	end

end)
