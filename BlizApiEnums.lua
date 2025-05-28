-- BlizApiEnums.lua
-- a bunch of IntelliJ-EmmyLua annotations
-- I should be using @enum but it's not supported by... my version of EmmyLua?  Something?  Regardless, @enum isn't recognized by my IDE
-- ref: Interface/FrameXML/UI_shared.xsd

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the Ufo

---@class RaidMarker
RaidMarker = {
    STAR     = "STAR",
    CIRCLE   = "CIRCLE",
    DIAMOND  = "DIAMOND",
    TRIANGLE = "TRIANGLE",
    MOON     = "MOON",
    SQUARE   = "SQUARE",
    CROSS    = "CROSS",
    SKULL    = "SKULL",
}

RaidMarkerTexture = {
    [RaidMarker.STAR    ] = ICON_LIST[1].. "0|t", -- why?!?!?!  fuck you yet again, Bliz
    [RaidMarker.CIRCLE  ] = ICON_LIST[2].. "0|t",
    [RaidMarker.DIAMOND ] = ICON_LIST[3].. "0|t",
    [RaidMarker.TRIANGLE] = ICON_LIST[4].. "0|t",
    [RaidMarker.MOON    ] = ICON_LIST[5].. "0|t",
    [RaidMarker.SQUARE  ] = ICON_LIST[6].. "0|t",
    [RaidMarker.CROSS   ] = ICON_LIST[7].. "0|t",
    [RaidMarker.SKULL   ] = ICON_LIST[8].. "0|t",
}

---@class MouseClick
MouseClick = {
    ANY    = "any",
    LEFT   = "LeftButton",
    RIGHT  = "RightButton",
    MIDDLE = "MiddleButton",
    FOUR   = "Button4",
    FIVE   = "Button5",
    SIX    = "Button6", -- there is no "Button6" in the API docs, so,  I've reserved this for use by my keybind code
}

---@class Anchor
Anchor = {
    LEFT        = "LEFT",
    RIGHT       = "RIGHT",
    CENTER      = "CENTER",
    BOTTOM      = "BOTTOM",
    TOP         = "TOP",
    TOPLEFT     = "TOPLEFT",
    TOPRIGHT    = "TOPRIGHT",
    BOTTOMLEFT  = "BOTTOMLEFT",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

---@class TooltipAnchor
TooltipAnchor = {
    BOTTOM_LEFT = "ANCHOR_BOTTOMLEFT",
    CURSOR      = "ANCHOR_CURSOR",
    LEFT        = "ANCHOR_LEFT",
    NONE        = "ANCHOR_NONE",
    PRESERVE    = "ANCHOR_PRESERVE",
    RIGHT       = "ANCHOR_RIGHT",
    TOP_LEFT    = "ANCHOR_TOPLEFT",
    TOP_RIGHT   = "ANCHOR_TOPRIGHT",
}

---@class FrameType
FrameType = {
    FRAME           = "Frame",
    ARCHAEOLOGY_DIG_SITE_FRAME = "ArchaeologyDigSiteFrame",
    BROWSER         = "Browser",
    BUTTON          = "Button",
    CHECK_BUTTON    = "CheckButton",
    CHECKOUT        = "Checkout",
    CINEMATIC_MODEL = "CinematicModel",
    COLOR_SELECT    = "ColorSelect",
    COOLDOWN        = "Cooldown",
    DRESS_UP_MODEL  = "DressUpModel",
    EDIT_BOX        = "EditBox",
    FOG_OF_WAR_FRAME = "FogOfWarFrame",
    GAME_TOOLTIP     = "GameTooltip",
    MESSAGE_FRAME    = "MessageFrame",
    MODEL            = "Model",
    MODEL_SCENE      = "ModelScene",
    MOVIE_FRAME      = "MovieFrame",
    OFF_SCREEN_FRAME = "OffScreenFrame",
    PLAYER_MODEL     = "PlayerModel",
    QUEST_POIFrame   = "QuestPOIFrame",
    SCENARIO_POIFrame = "ScenarioPOIFrame",
    SCROLL_FRAME      = "ScrollFrame",
    SIMPLE_HTML       = "SimpleHTML",
    SLIDER            = "Slider",
    STATUS_BAR        = "StatusBar",
    TABARD_MODEL      = "TabardModel",
    UNIT_POSITION_FRAME = "UnitPositionFrame",
}

---@class Script -- widget script handlers
Script = {
    ON_LOAD              = "OnLoad", --func(self) - object is created.
    ON_HIDE              = "OnHide", --func(self) - widget's visibility changes to hidden.
    ON_ENTER             = "OnEnter", --func(self, motion) - cursor enters the widget's interactive area.
    ON_LEAVE             = "OnLeave", --func(self, motion) - mouse cursor leaves the widget's interactive area.
    ON_MOUSE_DOWN        = "OnMouseDown", --func(self, button) - mouse button is pressed while the cursor is over the widget.
    ON_MOUSE_UP          = "OnMouseUp", --func(self) - widget becomes visible.
    ON_MOUSE_WHEEL       = "OnMouseWheel", --func(self, requested) - animation group finishes animating.
    ON_ATTRIBUTE_CHANGED = "OnAttributeChanged", --func(self, key, value) - secure frame attribute is changed.
    ON_SIZE_CHANGED      = "OnSizeChanged", --func(self, width, height) - frame's size changes
    ON_EVENT             = "OnEvent", --func(self, event, ...) - any and all events.
    ON_UPDATE            = "OnUpdate", -- func(self, elapsed) - Invoked on every frame, as in, the "frame" in Frame Per Second.
    ON_DRAG_START        = "OnDragStart", --func(self, button) - mouse is dragged starting in the frame
    ON_DRAG_STOP         = "OnDragStop", --func(self) - mouse button is released after a drag started in the frame,
    ON_RECEIVE_DRAG      = "OnReceiveDrag", --func(self) - mouse button is released after dragging into the frame.
    PRE_CLICK            = "PreClick", --func(self, button, down) - before `OnClick`.
    ON_CLICK             = "OnClick", --func(self, self, button, down) - clicking a button.
    POST_CLICK           = "PostClick", --func(self, button, down) - after `OnClick`.
    ON_DOUBLE_CLICK      = "OnDoubleClick", --func(self, self, button) - double-clicking a button.
    ON_VALUE_CHANGED     = "OnValueChanged", --func(self, value, userInput) - the slider's or status bar's value changes.
    ON_MIN_MAX_CHANGED   = "OnMinMaxChanged", --func(self, min, max) - the slider's or status bar's minimum and maximum values change.
    ON_UPDATE_MODEL      = "OnUpdateModel",
    ON_MODEL_CLEARED     = "OnModelCleared",
    ON_MODEL_LOADED      = "OnModelLoaded", --func(self) - model is loaded
    ON_ANIM_STARTED      = "OnAnimStarted", --func(self) - model's animation starts
    ON_ANIM_FINISHED     = "OnAnimFinished", --func(self) - model's animation finishes
    ON_ENTER_PRESSED     = "OnEnterPressed", --func(self) - pressing Enter while the widget has focus
    ON_ESCAPE_PRESSED    = "OnEscapePressed", --func(self) - pressing Escape while the widget has focus
    ON_SPACE_PRESSED     = "OnSpacePressed", --func(self) - pressing Space while the widget has focus
    ON_TAB_PRESSED       = "OnTabPressed", --func(self) - pressing Tab while the widget has focus
    ON_TEXT_CHANGED      = "OnTextChanged", --func(self, userInput) - changing the value
    ON_TEXT_SET          = "OnTextSet", --func(self) - setting the value programmatically
    ON_CURSOR_CHANGED    = "OnCursorChanged", --func(self, x, y, w, h) - moving the text insertion cursor
    ON_INPUT_LANGUAGE_CHANGED = "OnInputLanguageChanged", --func(self, language) - changing the language input mode 
    ON_EDIT_FOCUS_GAINED    = "OnEditFocusGained", --func(self) - gaining edit focus
    ON_EDIT_FOCUS_LOST      = "OnEditFocusLost", --func(self) - losing edit focus
    ON_HORIZONTAL_SCROLL    = "OnHorizontalScroll", --func(self, offset) - the horizontal scroll position changes
    ON_VERTICAL_SCROLL      = "OnVerticalScroll", --func(self, offset) - the vertical scroll position changes
    ON_SCROLL_RANGE_CHANGED = "OnScrollRangeChanged", --func(self, xrange, yrange) - the scroll position changes 
    ON_CHAR_COMPOSITION     = "OnCharComposition", --func(self, text) - changing the input composition mode
    ON_CHAR                 = "OnChar", --func(self, text) - any text character typed in the frame.
    ON_KEY_DOWN             = "OnKeyDown", --func(self, key) - keyboard key is pressed if the frame is keyboard enabled
    ON_KEY_UP               = "OnKeyUp", --func(self, key) - keyboard key is released if the frame is keyboard enabled
    ON_GAME_PAD_BUTTON_DOWN = "OnGamePadButtonDown", --func(self, button) - gamepad button is pressed.
    ON_GAME_PAD_BUTTON_UP   = "OnGamePadButtonUp", --func(self, button) - gamepad button is released.
    ON_GAME_PAD_STICK       = "OnGamePadStick", --func(self, stick, x, y, len) - gamepad stick is moved
    ON_COLOR_SELECT         = "OnColorSelect", --func(self, r, g, b) - ColorSelect frame's color selection changes
    ON_HYPERLINK_ENTER      = "OnHyperlinkEnter", --func(self, link, text, region, left, bottom, width, height) - mouse moves over a hyperlink on the FontInstance object
    ON_HYPERLINK_LEAVE      = "OnHyperlinkLeave", --func(self) - mouse moves away from a hyperlink on the FontInstance object
    ON_HYPERLINK_CLICK      = "OnHyperlinkClick", --func(self, link, text, button, region, left, bottom, width, height) - mouse clicks a hyperlink on the FontInstance object
    ON_MESSAGE_SCROLL_CHANGED = "OnMessageScrollChanged",
    ON_MOVIE_FINISHED         = "OnMovieFinished", --func(self) - a movie frame's movie ends
    ON_MOVIE_SHOW_SUBTITLE    = "OnMovieShowSubtitle", --func(self, text) - Runs when a subtitle for the playing movie should be displayed
    ON_MOVIE_HIDE_SUBTITLE    = "OnMovieHideSubtitle", --func(self) - Runs when the movie's most recently displayed subtitle should be hidden
    ON_TOOLTIP_SET_DEFAULT_ANCHOR = "OnTooltipSetDefaultAnchor", --func(self) - the tooltip is repositioned to its default anchor location 
    ON_TOOLTIP_CLEARED        = "OnTooltipCleared", --func(self) - the tooltip is hidden or its content is cleared
    ON_TOOLTIP_ADD_MONEY      = "OnTooltipAddMoney", --func(self, cost, maxcost) - an amount of money should be added to the tooltip
    ON_TOOLTIP_SET_UNIT       = "OnTooltipSetUnit", --func(self) - the tooltip is filled with information about a unit
    ON_TOOLTIP_SET_ITEM       = "OnTooltipSetItem", --func(self) - the tooltip is filled with information about an item
    ON_TOOLTIP_SET_SPELL      = "OnTooltipSetSpell",
    ON_TOOLTIP_SET_QUEST      = "OnTooltipSetQuest", --func(self) - the tooltip is filled with information about a quest
    ON_TOOLTIP_SET_ACHIEVEMENT= "OnTooltipSetAchievement", --func(self) - the tooltip is filled with information about an achievement
    ON_TOOLTIP_SET_FRAMESTACK = "OnTooltipSetFramestack", --func(self, highlightFrame) - the tooltip is filled with a list of frames under the mouse cursor
    ON_TOOLTIP_SET_EQUIPMENT_SET = "OnTooltipSetEquipmentSet", --func(self) - the tooltip is filled with information about an equipment set 
    ON_ENABLE           = "OnEnable", --func(self) - frame is enabled.
    ON_DISABLE          = "OnDisable", --func(self) - frame is disabled.
    ON_ARROW_PRESSED    = "OnArrowPressed", --func(self, key)
    ON_EXTERNAL_LINK    = "OnExternalLink",
    ON_BUTTON_UPDATE    = "OnButtonUpdate",
    ON_ERROR            = "OnError",
    ON_DRESS_MODEL      = "OnDressModel", --func(self) - modelscene model is updated
    ON_COOLDOWN_DONE    = "OnCooldownDone", --func(self) - cooldown has finished
    ON_PAN_FINISHED     = "OnPanFinished", --func(self) - camera has finished panning
    ON_UI_MAP_CHANGED   = "OnUiMapChanged", --func(self, uiMapID)
    ON_REQUEST_NEW_SIZE = "OnRequestNewSize",
}

---@class FrameStrata
FrameStrata = {
    PARENT = "PARENT",
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP",
    BLIZZARD = "BLIZZARD",
}

---@class Drawlayer
Drawlayer = {
    BACKGROUND = "BACKGROUND",
    BORDER = "BORDER",
    ARTWORK = "ARTWORK",
    OVERLAY = "OVERLAY",
    HIGHLIGHT = "HIGHLIGHT",
}

---@class Mark
Mark = {
    TANK       = 1, -- 🛡️
    HEALER     = 2, -- ⨁
    DPS        = 3, -- †
    BLIZZARD   = 4, -- BLIZ
    QUEST      = 5, -- !
    QUESTION   = 6, -- ?
    FIRE       = 7, -- 🔥
    LOCK       = 8, -- 🔒
    ALLIANCE   = 9, -- 🦁
    HORDE      = 10, -- Ω
    UP         = 11, -- ↑
    DOWN       = 12, -- ↓
    CHECK      = 13, -- ✓
    EX         = 14, -- ✕
    NO         = 15, -- 🚫
    INFO       = 16, -- ⓘ
    CROWN      = 17, -- 👑
    SHIELD     = 18, -- 🛡
    SWORD      = 19, -- †
    LOOT       = 20, -- 💰
    NOLOOT     = 21, -- 🚫💰
    DICE       = 22, -- 🎲
    COIN       = 23, -- 🤑
    -- WARRIOR    = 24,
    -- MAGE       = 25,
    -- ROGUE      = 26,
    -- DRUID      = 27,
    -- HUNTER     = 28,
    -- SHAMAN     = 29,
    -- PRIEST     = 30,
    -- WARLOCK    = 31,
    -- PALADIN    = 32,
    -- DEATHKNIGHT= 33,
    -- MONK       = 34,
}

MarkTexture = {
    [Mark.TANK]     = "|TINTERFACE\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t",
    [Mark.HEALER]   = "|TINTERFACE\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t",
    [Mark.DPS]      = "|TINTERFACE\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t",
    [Mark.BLIZZARD] = "|TINTERFACE\\CHATFRAME\\UI-CHATICON-BLIZZ:12:20:0:0:32:16:4:28:0:16|t",
    [Mark.QUEST]    = "|TINTERFACE\\GOSSIPFRAME\\AVAILABLEQUESTICON:0:0:0:0|t",
    [Mark.QUESTION] = "|TINTERFACE\\RAIDFRAME\\READYCHECK-WAITING:14:14:0:0|t",
    [Mark.FIRE]     = "|TINTERFACE\\HELPFRAME\\HOTISSUEICON:0:0:0:0|t",
    [Mark.LOCK]     = "|TINTERFACE\\LFGFRAME\\UI-LFG-ICON-LOCK:14:14:0:0:32:32:0:28:0:28|t",
    [Mark.ALLIANCE] = "|TINTERFACE\\TARGETINGFRAME\\UI-PVP-ALLIANCE:19:16:0:0:64:64:0:32:0:38|t",
    [Mark.HORDE]    = "|TINTERFACE\\TARGETINGFRAME\\UI-PVP-HORDE:18:19:0:0:64:64:0:38:0:36|t",
    [Mark.UP]       = "|TINTERFACE\\PETBATTLES\\BATTLEBAR-ABILITYBADGE-STRONG-SMALL:0|t",
    [Mark.DOWN]     = "|TINTERFACE\\PETBATTLES\\BATTLEBAR-ABILITYBADGE-WEAK-SMALL:0|t",
    [Mark.CHECK]    = "|TINTERFACE\\RAIDFRAME\\READYCHECK-READY:14:14:0:0|t",
    [Mark.EX]       = "|TINTERFACE\\RAIDFRAME\\READYCHECK-NOTREADY:14:14:0:0|t",
    [Mark.NO]       = "|TINTERFACE\\BUTTONS\\UI-GROUPLOOT-PASS-UP:14:14:0:0|t",
    [Mark.INFO]     = "|TINTERFACE\\FRIENDSFRAME\\INFORMATIONICON:14:14:0:0|t",
    [Mark.CROWN]    = "|TINTERFACE\\GROUPFRAME\\UI-GROUP-LEADERICON:14:14:0:0|t",
    [Mark.SHIELD]   = "|TINTERFACE\\GROUPFRAME\\UI-GROUP-MAINTANKICON:14:14:0:0|t",
    [Mark.SWORD]    = "|TINTERFACE\\GROUPFRAME\\UI-GROUP-MAINASSISTICON:14:14:0:0|t",
    [Mark.LOOT]     = "|TINTERFACE\\GROUPFRAME\\UI-GROUP-MASTERLOOTER:14:14:0:0|t",
    [Mark.NOLOOT]   = "|TINTERFACE\\COMMON\\ICON-NOLOOT:13:13:0:0|t",
    [Mark.DICE]     = "|TINTERFACE\\BUTTONS\\UI-GROUPLOOT-DICE-UP:14:14:0:0|t",
    [Mark.COIN]     = "|TINTERFACE\\BUTTONS\\UI-GROUPLOOT-COIN-UP:14:14:0:0|t",
    -- [RandoIcon.WARRIOR]  = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:0:64:0:64|t",
    -- [RandoIcon.MAGE]     = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:64:128:0:64|t",
    -- [RandoIcon.ROGUE]    = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:128:196:0:64|t",
    -- [RandoIcon.DRUID]    = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:196:256:0:64|t",
    -- [RandoIcon.HUNTER]   = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:0:64:64:128|t",
    -- [RandoIcon.SHAMAN]   = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:64:128:64:128|t",
    -- [RandoIcon.PRIEST]   = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:260:256:128:196:64:128|t",
    -- [RandoIcon.WARLOCK]  = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:196:256:64:128|t",
    -- [RandoIcon.PALADIN]  = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:0:64:128:196|t",
    -- [RandoIcon.DEATHKNIGHT] = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:256:256:64:128:128:196|t",
    -- [RandoIcon.MONK]        = "|TINTERFACE\\WORLDSTATEFRAME\\ICONS-CLASSES:14:14:0:0:260:256:128:196:128:196|t",
}

-- some useful regular expressions I used to reformat raw listings into the above code
-- REGEX 1
-- <xs:element name="([^"]*)".+
-- $1 = "$1",
-- REGEX 2
-- ^On([A-Z])([a-z]+)
-- ON_$1\U$2_
-- REGEX 2 continued
-- _([A-Z])([a-z]+)
-- _$1\U$2_
--  ([^ = "([^",
