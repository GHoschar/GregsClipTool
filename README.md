# GregsClipTool

Quick Start Guide
=================

Start the ClipTool
------------------
* Extract files from zip into the folder of your choice. 
* DoubleClick GregsClipTool.bat.
* Minimize (but DO NOT CLOSE) the Console Window.
* Use the GUI window to manage and transform your clipboard contents.

IMPORTANT!
----------
Be careful about clipping sensitive info when sharing your screen!
	- Even if copied from a masked password field, ClipTool shows PLAIN TEXT.
	- Minimize GregsClipTool, collapse to TitleBar, or move it to another screen.
	- Make sure to Remove or Clear sensitive History entries.

Note
----
The Console window is *not* hidden by default because Cybersecurity at my organization is very wary PS scripts that open in a hidden window. Leaving it visible and forcing the user to  manually minimize it makes it less worrisome to them.

GUI Highlights
--------------
* Mouse over the GUI to expand it. 
	- Modify or turn off Mouse Hover features on Settings Tab.
* Copy/Cut/Paste text any way you like, it shows in the box on top.
* Most controls have helpful ToolTips. (More ToolTips to come!)
* Click GroupBoxes with ⭭ or ⭱ symbols to expand or collapse them.
* ActionBox:
	- Click Action buttons to transform the clipboard.
	- Make new Actions on the fly! (Way beyond the scope of a Quick Start.)
	- File Menu > Save Actions to save your changes to Actions.
	- Right click actions and groups for context menu.
* History Tab:
	- Records your clipboard history.
	- Click a history entry to copy it to the clipboard.
	- Right click for history context menu.
	- Ctrl or Shift click to Select multiple history entries.
* Settings Tab:
	- Change settings and configure features here.
	- File Menu > Save Settings to be 100% certain settings saved.
		Auto-save is finicky right now.

Detailed guide to come!

Background
==========
GregsClipTool is:
 - A powerful clipboard management multi-tool that users can expand on the fly
 - A learning experience in PowerShell and WPF

In early 2020, I found myself working in the IT department of a hospital that was closing, my long term girlfriend had just passed away, and a global pandemic was stirring. I managed to get a new IT role in the parent company, but the details of that role were still being ironed out. I went through come transitional roles during that period, helping out wherever my knowledge and skills could bring value.

One of those roles was in the enterprise user provisioning department and one of the tasks there involved the frequent copy/edit/paste activities. One in particular that I sometimes had to do hundreds of time a day was to copy a name in "first middle last (ID)" format to "ID_First_Last" format for a filename. I didn't think security would allow AutoHotKey, but everyone in UserProv was comfortable with PowerShell, so I wrote a short script to read the clipboard and transform the contents. Everyone that worked that queue loved the result. "Copy, click PS window, run script, paste" was much faster than multiple copies and pastes or moving it to a notepad to edit it.

I wasn't satisfied though. I wanted a button on screen to do it with a single click, or even better a hot key. As I studied how to make it happen, the scope grew and it became a dynamic platform where I could design multiple transform buttons and track clipboard history. In the process I've learned more about PowerShell and WPF than I had anticipated.

In order to share this powerful tool with world and perhaps give others a springboard to learn some of the arcane secrets of PowerShell and WPF, it is now on GitHub.

The code is messy and isn't well optimized nor does it follow all best practices, but the tool works well.

Resources
=========
The following sites and articles have been extremely helpful during the development of this tool.

General PowerShell
------------------
* https://docs.microsoft.com/en-us/powershell/
	Microsoft's PowerShell documentation has all the deepest details and I refer here first whenever I have any questions.

* https://ss64.com/ps/
	Great resource to help with general PowerShell information when the MS docs are still a little confusing for a fledgling developer.

Windows Presentation Foundation (WPF)
-------------------------------------
* https://docs.microsoft.com/en-us/dotnet/desktop/wpf/
	Microsoft's documentation for WPF. Another site I frequent almost daily in the course of this project.

* https://www.wpf-tutorial.com/
	Good overall WPF primer for beginners, if you can stand the heavy advertising. 

* https://stackoverflow.com/questions/6792275/how-to-create-custom-window-chrome-in-wpf
	This page got me started with customizing my own Window Chrome.

WPF in PowerShell
-----------------
* https://learn-powershell.net/2014/07/24/building-a-clipboard-history-viewer-using-powershell/
	Boe Prox already did most of the groundwork for this project before I ever had the idea. Imagine my shock on seeing this page! I've incorporated most of what he did there, and expanded on it in my own way.

* More Boe Prox gold. I highly recommend his whole site if you like PowerShell, but these two go into detail on several important elements of this project.
	* https://learn-powershell.net/2012/09/13/powershell-and-wpf-introduction-and-building-your-first-window/
	* https://learn-powershell.net/2012/10/14/powershell-and-wpf-writing-data-to-a-ui-from-a-different-runspace/

* https://stackoverflow.com/questions/52405852/link-wpf-xaml-to-datagrid-in-powershell
	Great explanation for using Datagrids in PowerShell.

Dynamic script within PowerShell
--------------------------------
* http://kevinmarquette.blogspot.com/2015/11/powershell-script-injection-with.html
	Points out an important security feature when loading and executing scriptblocks and a disturbing detail in its use.

* https://powershell.org/forums/reply/19606/
	Thanks Dave Wyatt for helping me make sense of ScriptBlock.CheckRestrictedLanguage()

