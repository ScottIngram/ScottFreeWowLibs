-- Bliz Template Annotations
-- a bunch of IntelliJ-EmmyLua annotations that
-- define the inheritance tree formed by Bliz's various FooTemplate XML definitions and their mixin fields

---@alias SecureFrameTemplate            nil
---@alias SecureActionButtonTemplate     SecureFrameTemplate | SecureActionButtonMixin
---@alias FlyoutPopupButtonTemplate      FlyoutPopupButtonMixin -- this is a button on the flyout
---@alias ActionButtonTemplate           BaseActionButtonMixin | ActionButtonSpellFXTemplate | FlyoutButtonTemplate
---@alias ActionButtonSpellFXTemplate    nil -- defines only UI layout, not behavior
---@alias FlyoutButtonTemplate           FlyoutButtonMixin -- this is the button used to toggle on and off a FlyoutPopupMixin
---@alias SmallActionButtonTemplate      SmallActionButtonMixin | ActionButtonTemplate
---@alias SpellFlyoutPopupButtonTemplate SpellFlyoutPopupButtonMixin | SmallActionButtonTemplate | FlyoutPopupButtonTemplate
---@alias FlyoutPopupTemplate            FlyoutPopupMixin


-------------------------------------------------------------------------------
-- Research Notes
-------------------------------------------------------------------------------
--[[

As shocking as it may sound,
I don't think any of my code is actually using anything even slightly related to ActionButton.
It doesn't seem to be any sort of parent to any of the "classes" I use in UFO.
It doesn't appear in any of the usual mechanisms: inherit, mixin, CreateFromMixins(), etc. of the "classes" used by UFO.
Yes, UFO uses things like SmallActionButtonTemplate, ActionButtonTemplate, SmallActionButtonMixin, etc.
But, lolz, despite the names, none of those derive from anything close to ActionButton.
Way to fucking go, yet a-goddam-gain Blizzard.  How many hours of my life do I have to waste because of your insane code.

-- The following research ultimately does not involve UFO but is left here as a reminder.

ActionButton should be treated as also an ActionBarButtonEventsFrame
because of this line in ActionButton.lua -> ActionBarActionButtonMixin:OnLoad()
ActionBarButtonEventsFrame:RegisterFrame(self);
ActionBarButtonEventsFrame

Due to this line in Interface/AddOns/Blizzard_ActionBar/Mainline/ActionButtonOverrides.lua
ActionBarActionButtonDerivedMixin = CreateFromMixins(ActionBarActionButtonMixin);
then every ActionBarActionButtonDerivedMixin is also a ActionBarActionButtonMixin
such classes include... huh, only one.
	<CheckButton name="ActionBarButtonCodeTemplate" inherits="SecureActionButtonTemplate, QuickKeybindButtonTemplate, ActionButtonSpellFXTemplate" virtual="true" mixin="ActionBarActionButtonDerivedMixin">
but also (thanks to inheritance)
	<CheckButton name="ActionBarButtonTemplate" inherits="ActionButtonTemplate, ActionBarButtonCodeTemplate" virtual="true" mixin="ActionBarButtonMixin">

]]

