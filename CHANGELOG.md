# GregsClipTool Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
Upcoming features and known issues that I plan to address:
* Convert old Changelog entries to the current standard.
* Implement HotKeys
* Help menu with Quickstart, Manual, and About options
* File system safe names on action export (i.e. "Date/time" to "Datetime")
* Option to autorun a list of actions on clipboard change
* Option to run actions in their own runspace so intensive/long running actions do not bog down the UI.
* Allow user to choose if a loaded action with same Action ID overwrites existing one (Yes, No, Yes to all, No to all)


## [0.1.25] - 2025-09-05
### Fixed
* `Convert-ActionButtonToHash` gracefully handles erroneous hotkey and script values.

## [0.1.24] - 2025-09-02
### Fixed
* `Add-Favorite` now stores favorite text using Base64 encoding instead of HTML encoding.
  - Prevents unintended variable expansion (e.g. `$HOST`) when deploying favorites.
  - Fully supports multiline text and special characters.

## [0.1.23] - 2022-04-10
### Added
* The Fields Tab context menu gets two new commands to replace text in 
	the current Clip.
	- Both replace the text matching the selected field's Name with the 
		selected field's Value.
	- RegEx version treats Name as a Regular Expression.
	- Plain version matches directly on Name as plain text.
* When the History box is scrolled to the bottom, it will automatically scroll 
	down as new values come in.
* New Actions:
	- Sort Lines Action in the Multiline group will sort the lines 
			alphabetically. It may be a good idea to Trim Lines before you sort them.
	- Base64 Encode and Base64 Decode actions in the Codecs group convert 
		clip between Unicode and base64.
	- SendKeys action group:
		* Send Clip Action can be used to send the current Clipboard contents to applications that do not normally allow pasting. (It may not work with some applications.)

				To use the Send Clip action:
					1) Make sure the text you want to send is in the Current 
						Clipboard Contents box.
					2) Click in the target application, exactly where you want the 
						text to appear.
					3) Click the Send Clip action button.
					4) The text should appear in the target area as if you had 
						typed it manually.
		* Send Clip {} Action works as Send Clip except it does not encode 
			curly braces ({}). This allows you to send special keycodes.
			See [link](https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.sendkeys.send?view=net-5.0)

	- ClipFont action group:
		* ClipBox Font action sets the current clip to the name of the 
			display font in the clipbox. (Primarily for debugging.)
		* ClipBox Normal sets the display font of the Current Clipboard 
			Contents Box to Segoe UI (The default)
		* ClipBox Mono (Lucida Console) action sets the ClipBox font to 
			monospaced Lucida Console.
		* ClipBox Mono (Mononoki) action sets the ClipBox font to 
			monospaced Mononoki. (font must be installed)
		* ClipBox Mono (Hermit) action sets the ClipBox font to 
			monospaced Hermit. (font must be installed)

	- Char action group:
		* The "HR" Actions below are intended to serve as a Horizontal 
			Rule in applications without built in alternatives.
			
			If the current clip starts with a number, the HR length will be 
			that many characters. Otherwise it is 74 characters.

			* HR_ Action copies a line of underscore characters (_) 
			* HR- Action copies a line of minus sign characters (-) 
			* HR= Action copies a line of equal sign characters (=) 
			* HR Action creates a Horizontal Rule of the last 
				non-whitespace character in the current clip. If the 
				clip is empty, the line is 74 underscores (_).

		* NBSP Action is a simple favorite of Non-Breaking SPace.
		* ✓ Action is a simple favorite that matches the label.
			
* New Deactivate-ClipToolWindow function provided for your custom 
	Action scripts to pass focus back to previous active window.

* The History Tab has a new status bar to report the number of entries and bytes stored.
	
### Changed
* Initialize-TemplateValue function now returns the current value if the template key already exists *or* the provided default.
* Switch versioning to major.minor.build.revision format in anticipation of GitHub release.
	Current version 0.1.23 corresponds to beta 23 in the old format.
* Silenced error message from [Windows.Clipboard]::SetText() method in Set-ClipboardText function.
* Improved display of scrollbar end buttons.
*  All references to "Greg's ClipTool" have been changed to "GregsClipTool"

### Fixed
* Filter boxes at the top of the Fields Tab work.
* Delimiter status in the title bar shows correct info on tool launch.
* "1 Line w/Dlm" Action in the Multiline group properly strips all ASCII 10 and ASCII 13 characters.
* ClipTool no longer tries to resize window if it is currently minimized or maximized.

### Removed
* Retired some actions. You can still load old copies, but they are no longer distributed with the tool.
	- Show Counts - Everything Show Counts reported is displayed in the Clip Label. (Settings > Window group > uncheck Hide Clip Label)
	- "First Words -> 1 Line" Action button was large, ugly, and very specific. You can get the same result by clicking "First Words" and then clicking "1 Line w/Dlm".

## Version 22 beta - 2021-02-03
	Features:
		* New Multiline Group Actions
			- "1 Line w/Dlm" combines a clip with multiple lines into a single line, using the UI under 
				delimiter setting.
			- "First Words -> 1 Line" takes the first word from each line and combines them into a 
				single line using the delimiter setting.
		* Clip Details Tab displays information about all the available formats on the current clipboard. 
			ClipTool currently manipulates only text.
		* Templates - dynamic Favorite Actions that will autofill preselected values when clicked.
			Initial implimentation is ready. Still experimental.
		* Window title shows version number.

	Bugfixes:
		* History Context Menu > Remove Selected is now case sensitive.

	Cleanup:
		* TextSide group updates:
			- TextSide actions now pull their EPIC data from TextSideData.txt instead of hardcoding it 
				into an action, allowing users to redefine it easier. Documentation to be provided soon.
			- The host/environments lines are output in alphabetical order by the hostname now, making it 
				match the order currently used by the serverside script.

## Version 21 beta - 2020-11-16
	Features:
		* Laying groundwork for Template favorites. Not ready yet.
	Bugfixes:
		* Case changing the current clip creates History entries.
		* Fixed an error in Start-ActionScript
		* Fixed errors in Action Button and Group movement.
	Cleanup:
		* Changed the group collapse buttons from arrows to a simple + and - symbols.
			(Alternates tried: ⭭⭱ ▶▼ ▷▽ ⊕⊖ ⊞⊟)
		* Move "Allow Action drag & drop ordering" Setting chekcbox to the Copy Actions group. The
			Window group is getting very crowded.
		* TextSide Actions
			- Env Map actions add the instance name ("ConnectCare" or "CarePATH") to the clip 
				history so you can easily paste it into the stationary.
			- Env Map actions split environment lists on any character that is not a letter, digit, or 
				underscore (_), allowing user input like "POC/TST/PRD/SHD".
			- Changed CC non-prod host from edc-epicnprd-1 to cc_nonprod
			- Added RSH alias to CarePATH side to map to SHDSC.
			- Cleaned up the call the "Init TextSide" action in each of the "Env MAP" actions

## Version 20 beta - 2020-10-28
	Features:
		• Reorder Actions and action groups!
			- Toggle drag & drop reordering by clicking:
				- Lock/key icon in the Actions label.
					□ The Lock ( 🔒 )  indicates drag and drop is off.
					□ The Key ( 🔑 ) indicates drag and drop is allowed.
				- Allow Action drag & drop reordering checkbox in Settings Tab > Window group box
			- Move Actions within their current group by clicking the ⌃ or ⌄ buttons in the Edit Action tab.
		• Copy button in the Edit Action tab creates a copy of the Action using the currently displayed 
			information. All further editing modifies the new copy, leaving the original unchanged.
		• The Current Clipboard Contents label shows extra info
			- Line, Word, and Character count of the current clip
			- Whitespace trim indicator
				- Underscore ( _ ) indicates the clip has whitespace at the beginning or end
				- Bottom bracket symbol ( ⎵ ) indicates there is NO whitespace at the beginning or end
	New Actions:
		• New Actions do not load automatically. Import them with the File > Load Actions command. File names 
			for actions in this release end with "_20".
		• Trim Lines Action in the Multiline group removes blank lines and trims the whitespace from the 
			beginning and end of each line in the current clip box.
		• Ensemble BAA favorite in the Sector group for denying Ensemble staff approvals that have the wrong form
		• Password action group has a slew of new actions:
			- PassPhrase generates a multiword passphrase. The PassPhrase action requires that the 
				eff_large_wordlist_sans_numbers.txt exist in the /actions folder. It is a list of 7776 words 
				recommended by the Electronic Frontier Foundation for use in passphrases. Feel free to modify 
				your list to suit your preferences.Enter a number in the clip box before clicking the PassPhrase 
				button to change the number of words generated. The default is 6 words.
			- PassString generates a string of characters intended for passwords. It is guaranteed to have 1 
				symbol, 1 numeral, 1 capital letter, and 1 lowercase letter (as long as the possible characters 
				include each type and the password is 4 or more characters long.)Enter a number in the clip box 
				before clicking the Strong Pass button to change the character length generated. The default is 24 
				characters.
			- Toggle "Begin w/ Letter" action toggles whether PassString must begin with a letter or not. When 
				turned on, generated strings will always begin with a capital or lowercase letter.
			- Show Pass Chars copies the list of possible characters used by PassString to the clipboard (and 
				shows them in the Clip Box).
			- Set Pass Chars uses the current clip box contents to define the possible characters for the 
				PassString action.
				- Divides the characters into capital letters, lowercase letters, numerals, and symbols (anything 
					that is not in the previous 3 types). PassString guarantees at least 1 character from each 
					provided class is present in the generated string.
				- Capitals and lowercase letters do not automatically provide their opposites. A PassString based 
					on "Abcdefg" will always have at least one "A" present (guaranteed 1 capital letter), but 
					never a lowercase "a" (it is not in that list).
				- Entering a character multiple times makes it more likely to be picked. "ABCCCCDEFG" will generate 
					on average four times as many Cs as it does Bs.
				- PassString (and ClipTool) supports the full range of Unicode including Emojis. (I don't guarantee 
					that your applications support them though!) 
					□ Pro tip: Use a non-breaking space in your passwords to make it harder to crack if someone sees 
						it in plaintext.
			- Default Pass Chars restores the default list of 95 characters easily typed from a standard computer 
				keyboard. (Includes space.)
			- Distinct Pass Chars removes commonly mistaken characters for people who have trouble distinguishing 
				similar looking characters. 
				- I recommend making long passwords when using these settings because it only leaves 40 possible 
					characters. 
		• Regex Escape and Regex Unescape actions in the Codecs group will escape or unescape the clip box text for 
			Regular Expressions.

	Bugfixes:
		• Clip Menu > Favorite command correctly creates a Favorite button.
		• Mouse scrolling in the Actions box works correctly.
		• If the Hide Menu setting is checked, the menu will collapse after any menu command is selected.
		• Changing the Group name to a shorter version of the old name in the Edit Action tab works correctly.

	Cleanup:
		• Settings > Window > "Compact View" changed to "Hide Clip Label" and "Hide Action Label" allowing 
			independent use of the new features for each label.
		• Settings > Window > "Hide *" options reordered to reflect actual positions in the display: 
			Title Status Display, Menu, Clip Label, then Action Label
		• Unicode characters throughout ps1 code file commented to reflect the name of the character
		• Removed numerous debug messages. The saving/loading messages are left in place.
		• Backend code to traverse the WPF tree for groups and their WrapPanels is more flexible.
		• Collapse to Title feature truly collapses to the Title instead of the Title Bar.

## Version 19 beta - 2020-10-01
	Features:
		* Action updates:
			- The DefaultActions.json file is no longer part of the package. It will not change any Actions 
				automatically and you will not lose any custom Actions you’ve created. 
				- To get the new actions, load them through File Menu > Load Actions. You will find a json 
					file for each action group if you want to pick and choose, or you can load 
					AllReleasedActions_19.json to load all of them.
				- Reordering actions and groups is not implemented yet. (Priorities, right?) The best way to 
					reorder them currently is to edit the save file. It is plain text in JSON format, so any 
					text editor works. They display in the same order they appear in the file.
			- Overhaul of TextSide actions:
				- Clearer labels/descriptions and more consistent display for generated history entries.
				- No longer shows unresolved environments in list intended to paste to stationary.
				- Restructured to make updates much easier when TextSide information changes.
			- New "QA Split" action in the Multiline group.
			- Several new actions in the Codecs and CMDB groups.
		* New Status section in the right of the title bar. 
			- Shows current delimiter value in a highly visible place.
			- Topmost Settings Button indicates at a glance if window is always on top, normal, or 
				comes to front when mouse enters. Mouseover for details, click to toggle.
			- Collapse Settings Button indicates if the window never collapses, collapses to ClipBox, or
				collapses to title. Mouseover for details, click to toggle.
			- You can Hide Title Status Display in Settings > Window Group.
		* New Clear History command in the History Context menu.
	Bugfixes:
		* Load Actions command correctly overwrites existing actions with the same ID.
		* Exporting action groups correctly writes only the actions in that group instead of the entire action list.
		* Minimizing ClipTool window with collapse options active no longer prevents it from expanding again.
	Cleanup:
		* File Menu > Re-Dock has been changed to "Return to Dock". (Shortcut is now D.)
		* The "autodock if Window Setting X contains 'r'" feature has been fully disabled.
		* History Context Menu > "Join Selected with ' '" changed to "Join Selected with Delimiter"
		* The Settings > Window Group moved below the Copy Options Group and now starts collapsed.

## Version 18 beta:
	* Default settings updated
		- Window Position settings default to blank.
		- DebugToFile defaults to false.
	* History Context Menu
		- New "Move Selected to End" command copies all selected history entries to the end of the history box.
			(Useful to reorder items for a Join Selected operation)
		- "Remove Selected" command removes all instances of the selected entries instead of only the first one.
