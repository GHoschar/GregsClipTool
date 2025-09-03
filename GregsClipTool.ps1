<# GregsClipTool
Author: Greg Hoschar
Contact me on GitHub @GHoschar

Files distributed with this package:
------------------------------------
GregsClipTool.bat  - batch file script that launches the application
GregsClipTool.ps1  - the core script
GregsClipTool.xaml - defines the GUI for the tool
README.md          - quick start guide and brief overview
CHANGELOG.md       - documents changes to the software

#>
Param(
    [switch]$NoSeparateRunspace
)
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms

$runningtime =  [system.diagnostics.stopwatch]::StartNew()
$appTitle = "GregsClipTool"
$appVersion = [version]'0.1.24'
if(!$psISE) {
    Write-Host "DO NOT CLOSE THIS WINDOW!"
    Write-Host "`tThis console window hosts the $appTitle application."
    Write-Host "`tClosing this will close the application as well."
    Write-Host "`n`tYou can minimize this window if you don't want to see it."
    Write-Host
}
Write-Host "Initializing $appTitle..."

$ClipToolCoreScript = { 

$script:defaultSettings = [ordered]@{
    Height = 450
    Width = 450
    X = ""
    Y = ""
    SplitterSize = 3
    ClipHeight = 54
    ActionWidth = 90
    WindowBackground = "#EEFFEE"
    AlwaysOnTop = $true
    HideActionLabel = $false
    HideClipLabel = $false
    HideMenu = $false
    HideTitleStatus = $false
    HideTemplateFields = $true
    HideClipDetails = $true
    AllowActionDragDrop = $false
    Delimiter = ' '
    MetaCopy = $true # allow Copy/Cut within CurrentClipboardContents without changing contents
    CopyHistoryOnClick = $true
    CollapseOnMouseLeave = $true
    CollapseToTitle = $false
    CollapseDelay = 0.5
    BringToFrontOnMouseEnter = $true
    OpacityOnMouseEnter = 1
    OpacityOnMouseLeave = .95
    HideSystemMessages = $true
    DebugToConsole = $true
    DebugToFile = $false
}

$script:Settings = New-Object PSObject -Property $script:defaultSettings

$script:settingsInitialized = $false
$script:unsavedSettings = $false #set $true if settings have changed and need to be saved.
<# Alternate expandable group labels suffixes
$script:expandableLabel = [char]::ConvertFromUtf32(0x2B6D) # downwards triangle-headed dashed arrow
$script:collapsibleLabel = [char]::ConvertFromUtf32(0x2B71) # upwards triangle-headed arrow to bar

$script:expandableLabel = [char]::ConvertFromUtf32(0x25B6) # black right-pointing triangle
$script:collapsibleLabel = [char]::ConvertFromUtf32(0x25BC) # black down-pointing triangle

$script:expandableLabel = [char]::ConvertFromUtf32(0x25B7) # white right-pointing triangle
$script:collapsibleLabel = [char]::ConvertFromUtf32(0x25BD) # white down-pointing triangle

$script:expandableLabel = [char]::ConvertFromUtf32(0x2295) # circled plus
$script:collapsibleLabel = [char]::ConvertFromUtf32(0x2296) # circled minus

$script:expandableLabel = [char]::ConvertFromUtf32(0x229E) # squared plus
$script:collapsibleLabel = [char]::ConvertFromUtf32(0x229F) # squared minus

$script:expandableLabel = "+"
$script:collapsibleLabel = "-"
#>
$script:expandableLabel = "+"
$script:collapsibleLabel = "-"

$script:collapsibleSuffixes = " [$script:expandableLabel|$script:collapsibleLabel]$"
$script:logfilename = "GCTlog$(Get-Date -Format "yyMMddHHmmss").csv"

# Action Button currently being editted in the Edit Action tab
$script:editAction = $null
# Hastable of hotkeys Key=ID Value=keycode.
$script:hotkeys = @{}

if($Runspacehash) {
    $script:localpath = $Runspacehash.localpath
} else {
    $script:localpath = $hostlocalpath
}

[xml]$xaml = Get-Content (join-path $script:localpath 'GregsClipTool.xaml')

$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load($reader)
$reader.Close()

if($Window) {


#These commands and variables will be accessible to scriptblocks from Action Buttons
[string[]]$allowedCommands = @('Import-LocalizedData', 'ConvertFrom-StringData', 'Write-Host', 'Out-Host', 'Join-Path')
[string[]]$allowedVariables = @('Window','unsavedSettings')

#Connect to Controls
$xaml.SelectNodes("//*/@*[name()='x:Name']|//*/attribute::Name").'#text' | %{
    if($_ -notin (Get-Variable).Name) {
        #Write-Host "Linking to $_"
        Set-Variable -Name ($_) -Value $Window.FindName($_)
        $allowedVariables += $_
    }
}

# New Functions
Function Add-ActionButton {
    Param(
        $actions,
        $choice
    )
    #$AddActionButtonDebug = $true
    if($choice -like "y*") {
        $choice = "Yes to All"
    } elseif ($choice -like "n*") {
        $choice = "No to All"
    }
    if($AddActionButtonDebug) {Write-Log "Add-ActionButton $actions"}
    $actionCheck = Get-AllDescendants $ActionBox | ?{$_.name -like "ab_*"}
    foreach($actionTemplate in $actions) {
        if($actionTemplate.name) {
            if($AddActionButtonDebug) {Write-Log "Action: $actionTemplate"}

            $actionButton = $null

            if($actionTemplate.id) {
                if($AddActionButtonDebug) {Write-Log "searching $($actionCheck.count) actions for button $($actionTemplate.id)"}
                $actionButton = $actionCheck | ?{$_.name -like $actionTemplate.id} | Select-Object -First 1
                if($AddActionButtonDebug) {Write-Log "$actionButton $($actionButton.count) found"}
<#
                if($actionButton) {
                    if($choice -nlike "*to all") {choice = }
                }
#>
            }
            if(!$actionButton) {
                if($AddActionButtonDebug) {Write-Log "Creating new action button"}
                $actionButton = New-Object System.Windows.Controls.Button
                $actionButton.AllowDrop = $true

                $actionButton.Add_Click({Start-ActionScript $this})

                $actionButton.Add_Drop({Complete-DragDrop $this $args[0] $args[1]})
                $actionButton.Add_PreviewMouseLeftButtonDown({
                    if($script:Settings.AllowActionDragDrop) {
                        $_.handled = $true
                        Start-DragDrop $this
                    }
                })

                # Context Menu
                $ContextMenu = New-Object System.Windows.Controls.ContextMenu
                $editOption = New-Object System.Windows.Controls.MenuItem
                $editOption.Header = "_Edit Action"
                $editOption.Add_Click({Edit-Action $this.Parent.PlacementTarget})
                $ContextMenu.AddChild($editOption)

                $deleteOption = New-Object System.Windows.Controls.MenuItem
                $deleteOption.Header = "_Remove Action"
                $deleteOption.Add_Click({Remove-Action $this.Parent.PlacementTarget})
                $ContextMenu.AddChild($deleteOption)

                $actionButton.ContextMenu = $ContextMenu
            }

            if(!$actionTemplate.id) {
                $id = "ab_" + ('{0:x}' -f (Get-Date).Ticks) # Hex
                #$id = [System.Convert]::ToBase64String([BitConverter]::GetBytes((Get-Date).Ticks)) # Base64
                $base = $id
                $n = 0
                while($ActionBox.FindName($id)) {
                    $n++
                    $id = "$($base)_$n"
                } 
                switch($actionTemplate.gettype().name) {
                    "PSCustomObject" {
                        if(!($actionTemplate | gm id)) {
                            $actionTemplate | add-member id $id
                        } else {
                            $actionTemplate.id = $id
                        }
                    }
                    "Hashtable" {
                        $actionTemplate.id = $id
                    }
                    default {
                        Write-Log "Unhandled action type $_"
                    }
                }

                if($AddActionButtonDebug) {Write-Log "Action ID: $id"}
            }

                    
            $actionButton.Name = $actionTemplate.id
            $actionButton.Content = $actionTemplate.name
            $actionButton.ToolTip = $actionTemplate.description
            if($actionTemplate.color) {$actionButton.Background=$actionTemplate.color}

            if($actionTemplate.script) {
                switch($actionTemplate.script.GetType().Name) {
                    "String" {$actionButton.Tag=[scriptblock]::Create($actionTemplate.script)}
                    "ScriptBlock" {$actionButton.Tag = $actionTemplate.script}
                    default {Write-Log "Undefined script for action button $($actionTemplate.name)."}
                }
            }

            if($Runspacehash) {
                $Runspacehash.LastButtonAdded = $actionButton
                $Runspacehash.LastButtonDefinition = $actionTemplate
            }

            $oldgroup = (Get-ParentGroup $actionButton).Header
            if($oldgroup -ne $actionTemplate.group) {
                if($oldgroup) {Remove-Action $actionButton}
                Add-ActionToGroup $actionButton $actionTemplate.group
            }
            $actionButton
        } # if($actionTemplate.name
    } # foreach($actionTemplate
}
$allowedCommands += 'Add-ActionButton'

Function Add-ActionToGroup {
    Param(
        $actionButton,
        $groupname = $null
    )
    $group = $null
    if($groupname) {
        $sanitizedGroupName = "agb_$($groupname -replace "\W",'')"
        foreach($g in $ActionBox.Children) {
            if($g.Name -eq $sanitizedGroupName) {
                $group = $g
                break
            }
        }
        if(!$group) { # group not found. Create it.
            $group = New-Object System.Windows.Controls.GroupBox
            $group.Name=$sanitizedGroupName
            $group.Header=$groupname
            Enable-CollapsibleElement $group
<#
            $scrollviewer = New-Object System.Windows.Controls.ScrollViewer
            $scrollviewer.VerticalScrollBarVisibility="Auto"
            $scrollviewer.AddChild((New-Object System.Windows.Controls.WrapPanel))
            $group.AddChild($scrollviewer)
#>
            $group.AddChild((New-Object System.Windows.Controls.WrapPanel))

            #drop zone
            $group.AllowDrop = $true
<#
            $group.Add_DragEnter({
                $sender = $args[0]
                $events = $args[1]
                Write-Log "$this DragEnter($sender, $events) - Tag=$($this.Tag)"
                if($this.Content.Visibility -eq "Collapsed") {
                    Toggle-GroupVisibility $this
                    $this.tag = (Get-Date).ToFileTime()
                }
            })
            $group.Add_DragLeave({
                Write-Log "$this DragLeave() - Tag=$((Get-Date).ToFileTime() - $this.Tag)"
                if($this.Tag -and ((Get-Date).ToFileTime() - $this.Tag) -gt 1000000) {
                    $this.Tag = $null
                    Toggle-GroupVisibility $this
                }
            })
#>
            $group.Add_Drop({Complete-DragDrop $this $args[0] $args[1]})
            $group.Add_MouseLeftButtonDown({Start-DragDrop $this})
<#
            $scrollviewer.AllowDrop = $true
            $scrollviewer.Add_Drop({Complete-DragDrop $this.parent $args[0] $args[1]})
#>
            $wrappanel = Get-ChildWrapPanel $group
            $wrappanel.AllowDrop = $true
            $wrappanel.Add_Drop({Complete-DragDrop $this.parent $args[0] $args[1]})
    
            # Context Menu
            $ContextMenu = New-Object System.Windows.Controls.ContextMenu
            $exportOption = New-Object System.Windows.Controls.MenuItem
            $exportOption.Header = "_Export Group"
            $exportOption.Add_Click({Get-ActionFileName ($this.Parent.PlacementTarget)})
            $ContextMenu.AddChild($exportOption)

            $deleteOption = New-Object System.Windows.Controls.MenuItem
            $deleteOption.Header = "_Remove Group"
            $deleteOption.Add_Click({Remove-Group $this.Parent.PlacementTarget})
            $ContextMenu.AddChild($deleteOption)

            $group.ContextMenu = $ContextMenu

            $ActionBox.AddChild($group)
        }
    } # if($groupname)

    if($group) {
        (Get-ChildWrapPanel $group).AddChild($actionButton)
    } else {
        $ActionBox.AddChild($actionButton)
    }

}
$allowedCommands += 'Add-ActionToGroup'

Function Add-Favorite {
    Param(
        [string]$text
    )

    # Pre-encode the raw favorite text so we never have to escape it into the script literal
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))

    Edit-Action (Add-ActionButton @{
        name        = 'Fav'
        group       = 'Favorites'
        description = "Copy Favorite Text: $text"
        # Decode at runtime; single-quoted Base64 is safe (no $ expansion, no quotes inside Base64 alphabet)
        script      = "`$b64='$b64';" +
                      "`$bytes=[Convert]::FromBase64String(`$b64);" +
                      "`$script:CopiedText=[Text.Encoding]::UTF8.GetString(`$bytes);" +
                      "Set-ClipBoardText `$script:CopiedText"
    })
}
$allowedCommands += 'Add-Favorite'

Function Add-History {
    <# Helper function to provide easy access to action scripts. 
        Adds text to HistoryBox with option to scroll to to the bottom #>
    Param(
        [string]$text,
        [switch]$ScrollToBottom
    )
    if($HistoryBox.Parent.VerticalOffset -eq $HistoryBox.Parent.ScrollableHeight) {
        $ScrollToBottom = $true
    }
    [void]$Script:HistoryCollection.Add($text)

    Update-HistoryStatus
    if($ScrollToBottom) {$HistoryBox.Parent.ScrollToBottom()}
}
$allowedCommands += 'Add-Favorite'

Function Apply-EditAction {
    #Write-Log "Apply-EditAction"
    $elements = Get-AllDescendants $EditActionTab
    #Write-Log "$($elements.count) elements returned"

    foreach($element in $elements) {
        switch -regex ($element.Name) {
            'tbact_Group' {
                # swap groups
                #$group = $script:editAction.Parent.Parent.Parent
                $group = Get-ParentGroup $script:editAction
                if(($group.Header -replace $script:collapsibleSuffixes,'').toLower() -ne $element.Text.toLower()){
                    Remove-Action $script:editAction
                    Add-ActionToGroup $script:editAction $element.Text
                }
                Break
            }
            "tbact_Tag" {
                # TODO: check script security
                $script:editAction.Tag = [scriptblock]::Create($element.Text)
                #Write-Log "Script updated to [$($script:editAction.Tag.GetType())] $($script:editAction.Tag) "
                Break
            }
            "tbact_" { # TextBox ACTion button field
                $script:editAction.(($element.Name -split "_")[1]) = $element.Text
                #Write-Log "Action Button $(($element.Name -split "_")[1]) updated to $($script:editAction.(($element.Name -split "_")[1]))"
            }
            "tbhk_" { # TextBox Hotkey not stored on the button itself
                $script:hotkeys[$script:editAction.Name] = $element.Text
                # TODO: hotkey functionality
                #Write-Log "Hotkey updated to $($script:hotkeys[$script:editAction.Name])"
            }
            "" { # Do nothing 
                Break
            }
            default {
                    Write-Log "Unhandled Edit Action element $element - $($element.name)"
            }
        } # switch($element.name
    } # foreach($element
} # Function Apply-EditAction
$allowedCommands += 'Apply-EditAction'

Function Apply-TemplateFieldFilters {
    param(
        $filter
    )
    [System.Windows.Data.CollectionViewSource]::GetDefaultView($Datagrid.ItemsSource).Filter = [Predicate[Object]]{
        Try {
            $nam = $dgf_Name.Text.Trim()
            $val = $dgf_Value.Text.Trim()
            $com = $dgf_Comments.Text.Trim()
            ((!$nam) -or ($nam -and ($args[0].Name -match [regex]::Escape($nam)))) -and 
                ((!$val) -or ($val -and ($args[0].Value -match [regex]::Escape($val)))) -and 
                ((!$com) -or ($com -and ($args[0].Comments -match [regex]::Escape($com))))
        } Catch {
            $True
        }
    }

<#
.Add_TextChanged({Apply-TemplateFieldFilters $this})

.Add_TextChanged({Apply-TemplateFieldFilters $this})

.Add_TextChanged({Apply-TemplateFieldFilters $this})


    [System.Windows.Data.CollectionViewSource]::GetDefaultView($Datagrid.ItemsSource).Filter = [Predicate[Object]]{
        Try {
            $args[0] -match [regex]::Escape($dgf.Text)
        } Catch {
            $True
        }
    }    
#>
} # Function Apply-TemplateFieldFilters
$allowedCommands += 'Apply-TemplateFieldFilters'

Function Clear-Viewer {
    [void]$Script:HistoryCollection.Clear()
    [void]$Script:SystemCollection.Clear()
    Clear-Template
    [Windows.Clipboard]::Clear()
    $CurrentClipBox.Text = ''
    $script:Previous = ''
    $script:CopiedTex = ''
    Update-HistoryStatus
}
$allowedCommands += 'Clear-Viewer'

Function Complete-DragDrop {
    param(
        $target,
        $sender,
        $event)
    if($script:Settings.AllowActionDragDrop) {
        #Write-Log "Complete-DragDrop target: $target`n - sender: $sender`n - Event: $event"
<#
        #foreach($p in @('data','originalsource','source','allowedeffects','effects','handled','keystates','routedevent')) {
        foreach($p in @('data','handled')) {
            Write-Log "`tevent $p = $($event.$p)"
        }
        Write-Log "-$($event.Data.GetFormats())-"
#>
        if(!$event.Handled) {
            Switch ($target.GetType()) {
                System.Windows.Controls.GroupBox {
                    Switch ($event.Data.GetFormats()) {
                        System.Windows.Controls.GroupBox { # group dropped on group. Move drop before target.
                            #Write-Log "group on group"
                            $event.Handled = $true
                            Move-Element -Element $event.Data.GetData("System.Windows.Controls.GroupBox") -Target $target -Container $ActionBox
                        }
                        System.Windows.Controls.Button { # button dropped on group. Move to end of group.
                            #Write-Log "button on group"
                            $event.Handled = $true
                            #if($target.Visibility -eq 'Collapsed') {Toggle-GroupVisibility $target}
                            Move-Element -Element $event.Data.GetData("System.Windows.Controls.Button") -Target $target -Container (Get-ChildWrapPanel $target)
                        }
                    } # Switch ...GetFormats()
                }
                System.Windows.Controls.Button {
                    If("System.Windows.Controls.Button" -in $event.Data.GetFormats()) { # Move dropped button before target
                        #Write-Log "button on button"
                        $event.Handled = $true
                        Move-Element -Element $event.Data.GetData("System.Windows.Controls.Button") -Target $target -Container $target.parent
                    }
                }
            }
        } # if(!$event.Handled)
    }
} # Function Complete-DragDrop
$allowedCommands += 'Complete-DragDrop'

Function Confirm-MenuHidden {
    if($script:Settings.HideMenu -and ($MenuBar.Visibility -ne 'Collapsed')) {$MenuBar.Visibility = 'Collapsed'}
} # Function Confirm-MenuHidden
$allowedCommands += 'Confirm-MenuHidden'

Function Convert-ActionButtonToHash {
    Param(
        $button
    )
    #$group = $button.Parent.Parent.Parent # Group > ScrollViewer > WrapPanel > Button
    $group = Get-ParentGroup $button
    #Write-Log "Group is $group [$($group.GetType())]"
    if($group -is [System.Windows.Controls.GroupBox]) {
        $group = $group.Header -replace $script:collapsibleSuffixes,''
        #Write-Log "Group was group $group"
    } else {$group = ''}
    [ordered]@{
        name=$button.Content
        id=$button.Name
        group=$group
        color=[string]$button.Background
        width=$button.Width
        height=$button.Height
        hotkey=$script:hotkeys[$button.Name]
        description=$button.Tooltip
        script=$button.Tag.toString()
    }
} # Function Convert-ActionButtonToHash
$allowedCommands += 'Convert-ActionButtonToHash'

function Convert-BytesToHexView {
    param(
        [byte[]]$bytes,
        #incoming byte stream
        [int]$line=8,
        # Bytes per line
        [int]$section=4,
        # Bytes per section
        [int]$max
        #if set, only read this many bytes

    )
    $streampos = 0
    $output = ''
    $chars = ''
    $size = $bytes.Count
    if($max) {$size = [math]::Min($max,$size)}
    for($pos = 0; $pos -lt $size;$pos++) {
        if($output) {
            if($pos%$line -eq 0) {
                $output += "| $chars`n"
                $chars = ''
            } elseif($pos%$section -eq 0) {
                $output += ' '
                $chars += ' '
            }
        }
        $output += ('{0:X2} ' -f $bytes[$pos])
        if($bytes[$pos] -gt 31 -and $bytes[$pos] -lt 127) {$chars += [char]$bytes[$pos]} else {$chars += '.'}
    }
    if($size%$line) {
        for($pos = $size; $pos%$line; $pos++) {
            if($pos%$section -eq 0) {
                $output += ' '
            }
            $output += '   '
        }
    }
    $output += "| $chars"
    if($size -lt $bytes.Count) {$output += "`n... $($bytes.Count - $size) bytes ommitted."}
    $output
}
$allowedCommands += 'Convert-BytesToHexView'

function ConvertTo-UnicodeList {
    #converts a string to a list of unicode characters
    param([string]$string)
    for($i=0; $i -lt $string.Length; $i++) {
        if([System.Char]::IsHighSurrogate($string[$i])) {
            [char]::ConvertFromUtf32(0x10000 + ($string[$i] - 0xD800) * 0x400 + $string[++$i] - 0xDC00)
        } else {
            $string[$i]
        }
    }
}
$allowedCommands += 'ConvertTo-UnicodeList'

Function Deactivate-ClipToolWindow {
    $oldstate = $Window.WindowState
    $script:overrideSizeDisplayUpdate = $true
    $Window.WindowState = 'Minimized';
    $Window.WindowState = $oldstate;
    $script:overrideSizeDisplayUpdate = $false
}
$allowedCommands += 'Deactivate-ClipToolWindow'

Function Edit-Action {
    Param($element)
    #Write-Log "Edit Action $element ($($element.ID))"
    $script:editAction = $element
    Sync-EditAction
    $EditActionTab.Visibility = "Visible"
    $TabControl.SelectedItem = $EditActionTab
    $tbact_Content.Focus()
}
$allowedCommands += 'Edit-Action'

Function Enable-CollapsibleElement {
    # make element collapsible.
    Param(
        $elem
    )
    #Write-Log "Enable-CollapsibleElement $elem"
    if($elem.Content.Visibility -eq 'Collapsed') {
            $elem.Header += " $script:expandableLabel"
    } else {
            $elem.Header += " $script:collapsibleLabel"
    }

    $elem.Add_MouseLeftButtonDown({if(!($script:Settings.AllowActionDragDrop -and ($this.parent -eq $ActionBpx))) {Toggle-GroupVisibility $this}})
}
$allowedCommands += 'Enable-CollapsibleElement'

Function Get-ActionFileName {
    Param($element = $null)
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.Title = "Save GregsClipTool Action File"
    $elemName = ''
    if($element) {
        # TODO: update to allow for saving individual buttons
        $elemName = $element.Header -replace $script:collapsibleSuffixes,''
        $SaveFileDialog.Title += " [$element group]"
    }
    $SaveFileDialog.initialDirectory = $script:localpath
    if( Test-Path (Join-Path $script:localpath 'actions') ) {
        $SaveFileDialog.initialDirectory = (Join-Path $script:localpath 'actions')
    }
    if($element) {
        $SaveFileDialog.FileName = "$($elemName -replace "[^[a-z][A-Z][0-9] ]",'').json"
    } else {
        $SaveFileDialog.FileName = "actions.json"
    }
    $SaveFileDialog.filter = "JSON format (*.json)|*.json"
    if($SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Log "Action Filename selected: $($SaveFileDialog.FileName)"
        Save-Actions  -filename ($SaveFileDialog.FileName) -start $element
    }
} # Function Get-ActionFileName

Function Get-AllDescendants {
    # TODO: make this a non-blocking function, user arraylist for $toCheck and remove $newCheck for efficiency
    Param($startElement)
    [System.Collections.ArrayList]$elements = @()
    $tocheck = @($startElement)
    while($tocheck.count) {
        $newcheck = @()
        foreach($sp in $tocheck) {
            #Write-Log "check - $sp"
            #if($sp -is [System.Windows.Controls.Control]) {
                $elements.Add($sp)
                #Write-log "added"
                if($sp -is [System.Windows.Controls.Panel]) {
                    #Write-log "panel"
                    $newcheck += $sp.Children
                } elseif ($sp -is [System.Windows.Controls.Decorator]) {
                    #Write-log "decorator"
                    $newcheck += $sp.Child
                } elseif ($sp.HasContent) {
                    #Write-log "has content"
                    $newcheck += $sp.Content
                }
            #}
        }
        $tocheck = @($newcheck)
    }
    return $elements
} # Get-AllDescendants

function Get-ChildWrapPanel {
# Finds the earliest child control that is a WrapPanel
    param(
        $element
    )
    Get-AllDescendants $element | ?{$_ -is [System.Windows.Controls.WrapPanel]} | Select-Object -First 1
}
$allowedCommands += 'Get-ChildWrapPanel'

Function Get-ClipBoardText {
    try{
        [Windows.Clipboard]::GetText()
    } catch {
    }
}
$allowedCommands += 'Get-ClipBoardText'

Function Get-CurrentScreen {
    #returns the System.Windows.Forms.Screen containing a point
    Param (
        [int]$testX = $Window.Left,
        [int]$testY = $window.Top
    )
    #$testPoint = (New-Object System.Windows.Point -ArgumentList $testX,$testY)
    $screens = [System.Windows.Forms.Screen]::AllScreens | select DeviceName,Primary,Bounds,WorkingArea,@{name="position";expression={[double]"$($_.Bounds.X).$($_.Bounds.Y)"}} | sort -Property position
    $return = $screens | ?{$_.Primary} #default to primary screen if none are found
    foreach($screen in $screens) {
        if(($testX -ge $screen.Bounds.X) -and 
            ($testX -lt $screen.Bounds.X+$screen.Bounds.Width) -and 
            ($testY -ge $screen.Bounds.Y) -and 
            ($testY -lt $screen.Bounds.Y+$screen.Bounds.Height)) {
                $return = $screen
            }
    } # foreach screen
    $return
} # Function Get-CurrentScreen
$allowedCommands += 'Get-CurrentScreen'

function Get-ParentGroup {
# Finds the earliest ancestor control that is a groupbox
    param(
        $element
    )
    do {
        #Write-Log "`$element = $element"
        $element = $element.parent
    } until (!$element -or $element -is [System.Windows.Controls.GroupBox] )
    #Write-Log "`$element = $element"
    $element
}
$allowedCommands += 'Get-ParentGroup'

Function Load-Actions {
    Param(
        $filename,
        $choice
    )
    if($Runspacehash) {$Runspacehash.actionfile = $filename}
    Write-log "Loading actions from $filename"
    # Action properties: name, hotkey, autorun checkbox;(appearance) width, height, color, group; description; script
    # $scriptBlock=[Scriptblock]::Create($string)
    Switch (($filename -split "\.")[-1]) {
        "json" {
            $content = Get-Content $filename -Raw 
            if($content.length) {
                $actionList = ConvertFrom-Json $content -ErrorAction SilentlyContinue
                Add-ActionButton $actionList -choice $choice
            }
        }
        "ps1" {
            $content = Get-Content $filename -Raw 
            if($content.length) {
                # TODO: filter potentially harmful script
                $actionList = [scriptblock]::Create($content)
                Add-ActionButton (& $actionList) -choice $choice
            }
        }
        default{
            Write-Log "Unrecognized action file format: $_"
        }
    }
} # Function Load-Actions
$allowedCommands += 'Load-Actions'

Function Load-Settings {
    Write-Log "Loading Settings from $script:localpath"
    #start with default settings
    $script:Settings = New-Object PSObject -Property $script:defaultSettings

    $content=""
    if(Test-Path (Join-Path $script:localpath "settings.json")) {
        $content = Get-Content (Join-Path $script:localpath "settings.json") -Raw
    }
    if($content.length) {
        $script:loadedSettings = ConvertFrom-Json $content -ErrorAction SilentlyContinue
        if($script:loadedSettings -ne $null) {
            foreach($prop in (Get-Member -InputObject $script:loadedSettings -MemberType NoteProperty).Name) {
                switch ($prop) {
                    "actionlist" {
                        # actions no longer come from the $script:Settings. Load-Actions instead.
                    }
                    "HideLabels" { # HideLabels has been split into HideActionLabel and HideClipLabel 
                        $script:Settings.HideActionLabel = $script:loadedSettings.$prop
                        $script:Settings.HideClipLabel = $script:loadedSettings.$prop
                    }
                    default {
                        #Write-Log "Before $prop `$script:Settings ($($script:Settings.$prop)) = `$script:loadedSettings ($($script:loadedSettings.$prop))"
                        $script:Settings.$prop = $script:loadedSettings.$prop
                        #Write-Log "After $prop `$script:Settings ($($script:Settings.$prop)) = `$script:loadedSettings ($($script:loadedSettings.$prop))"
                    }
                }
            }
        } else {
            Write-Log "Failed to import settings. Using default settings"
        }
    } else {
        Write-Log "Empty or missing save file. Using default settings"
    }

    Sync-Settings
    $script:unsavedSettings = $false
}
$allowedCommands += 'Load-Settings'

Function Move-Element {
    param(
        $Element,
        $Target,
        $Container
    )
    # TODO: get appropriate container if container is null
    # TODO: Move buttons in Edit button dialog - $target = "up" or $target = "down" means calc target
    if($Element -ne $Target) { # only move things if the element is not the target
        #Write-Log "Move-Element -Element $Element -Target $Target -Containter '$Container'"
        Switch ($Target) {
            {$_.GetType() -like "System.Windows.Controls*"} {
                $Target = $Container.Children.IndexOf($Target)
                if($target -lt 0) {$target = $Container.Children.Count}
            }
            {$_ -like 'u*'} {
                $Target = $Container.Children.IndexOf($Element)-1
            }
            {$_ -like 'd*'} {
                $Target = $Container.Children.IndexOf($Element)+1
            }
        }
        #Write-log "`$Target = '$Target'"
        if($Target -ge 0 -and $Target -le $Container.Children.count) {
            $oldparent = $Element.Parent
            $Element.Parent.Children.Remove($Element)
            if($Target -ge $Container.Children.count) {
                $Container.Children.Add($Element)
            } else {
                $Container.Children.Insert($Target,$Element)
            }
            if(!($oldParent.Children.Count)) {# empty panel
                #$group = $oldParent.Parent.Parent # Group > ScrollViewer > WrapPanel
                $group = Get-ParentGroup $oldParent
                if($group -is [System.Windows.Controls.GroupBox]) {
                    Remove-Group $group
                }
            }
        }
<#
        $found = $false
        for($i=0; $i -lt $Container.Children.count; $i++) {
            $e = $Container.Children[$i]
            if($e -ne $Element) { 
                if($e -eq $Target) {$found = $true}
                if($found) {
                    # pull $e out of the container and put it back in to move it to the end of the container
                    $Container.Children.Remove($e)
                    $Container.Children.Add($e)
                }
            }
        }
#>
    } else {
        Switch ($Element.GetType()) {
            'System.Windows.Controls.Button' {
                # Drop a button on itself? that's a click
                Start-ActionScript $Element
            }
            'System.Windows.Controls.GroupBox' {
                Toggle-GroupVisibility $Element
            }
        }
    }
}
$allowedCommands += 'Move-Element'

Function New-ActionButton {
    Edit-Action (Add-ActionButton @{
        name='New Action'
        description='Enter a brief description of the action'
        color='#FFDDDDDD'
        group='Custom'
        script='# TODO: Write PowerShell code here'
    })
}
$allowedCommands += 'New-ActionButton'

Function Remove-Action {
    Param($element)
    #Write-Log "Remove Action $element Name: $($element.Name)"
    # Remove from container
    $oldparent = $element.Parent
    $oldParent.Children.Remove($element)

    if(!($oldParent.Children.Count)) {# empty panel
        #$group = $oldParent.Parent.Parent # Group > ScrollViewer > WrapPanel
        $group = Get-ParentGroup $oldparent
        if($group -is [System.Windows.Controls.GroupBox]) {
            #Write-Log "Removing empty group $($group.Header)"
            Remove-Group $group
        }
    }
    #$element.Dispose()
}
$allowedCommands += 'Remove-Action'

Function Remove-Group {
    Param($element)
    # Remove from actionbox
    $element.Parent.Children.Remove($element)
}
$allowedCommands += 'Remove-Group'

Function Save-Actions {
    Param(
        # save all actions from $start down. no start means save all actions
        $start = $ActionBox,
        # use "Get-ActionFileName -element" to query user for path/filename. It will call this function.
        $filename
    )
    if(!$filename) {$filename = Join-Path $script:localpath 'DefaultActions.json'}
    Write-Log "Save-Actions -start $start -filename $filename"
    # list of hastable translations of buttons to export to save
    $actionList = [System.Collections.ArrayList]@()
    # list of elements to process for buttons
    
    if($start -is [System.Windows.Controls.Button]) {
        $actionList.Add((Convert-ActionButtonToHash $start))
    } else {
        $toProcess = Get-AllDescendants $start | ?{$_.name -like "ab_*"} 
        foreach($sp in $toProcess) {
            #Write-Log "Processing $($sp.Name) [$($sp.GetType())]"
            if($sp -is [System.Windows.Controls.Button]) {
                #Write-Log "Adding button $sp"
                $actionList += Convert-ActionButtonToHash $sp
            }
        } # foreach($sp in $toProcess)
    }
    $actionList | ConvertTo-Json | Out-File $filename
}
$allowedCommands += 'Save-Actions'

Function Save-Settings {
    $script:Settings | ConvertTo-Json | Out-File (Join-Path $script:localpath "settings.json")
    $script:unsavedSettings = $false
    Write-Log "Settings saved to $(Join-Path $script:localpath "settings.json")"
}
$allowedCommands += 'Save-Settings'

Function Sync-EditAction {
    #Write-Log "Sync-EditAction: init = $script:editActionInitialized"
    $elements = Get-AllDescendants $EditActionTab
    #Write-Log "$($elements.count) elements returned"

    foreach($element in $elements) {
        switch -Regex ($element.Name) {
            'tbact_Group' {
                #$element.Text = $script:editAction.Parent.Parent.Parent.Header -replace $script:collapsibleSuffixes,''
                $element.Text = (Get-ParentGroup $script:editAction).Header -replace $script:collapsibleSuffixes,''
                Break
            }
            "^tbact_" { # TextBox ACTion button field
                $element.Text = $script:editAction.(($element.Name -split "_")[1])
            }
            "^tbhk_" { # TextBox Hotkey not stored on the button itself
                if($script:editAction.Name -in $script:hotkeys.Keys) {
                    $element.Text = $script:hotkeys[$script:editAction.Name]
                }
            }
        } # switch
    } # foreach($element

    $script:editActionInitialized = $true
} # Function Sync-EditAction
$allowedCommands += 'Sync-EditAction'

Function Start-ActionScript {
    param(
        $button
    )
    if($button.Tag -is [ScriptBlock]) {
        & $button.Tag
    } else {
        Write-Log "Undefined script for action button $($actionTemplate.name)."
    }
}
$allowedCommands += 'Start-ActionScript'

Function Start-DragDrop {
    param($element)
    if($script:Settings.AllowActionDragDrop) {
        #Write-Log "Button: $($element.Content) Start-DragDrop"
        if($script:Settings.AllowActionDragDrop) {
            [System.Windows.DragDrop]::DoDragDrop($element, $element, [System.Windows.DragDropEffects]::Move)

            # close any groups that were openned during the drag
            foreach($grp in (Get-AllDescendants $ActionBox)){
                if($grp -is [System.Windows.Controls.GroupBox] -and $grp.Tag) {
                    $grp.tag = $null
                    Toggle-GroupVisibility $grp
                } # if($grp...
            }
        }
    }
} # function Start-DragDrop
$allowedCommands += 'Start-DragDrop'

Function Sync-Settings {
    #Write-Log "Sync-Settings: init = $script:settingsInitialized"
    $elements = @($SettingsBox.Children)
    $tocheck = @($elements)
    while($tocheck.count) {
        $newcheck = @()
        foreach($sp in $tocheck) {
            Switch($sp.GetType().Name) {
                "StackPanel" {
                    #Write-Log "Adding $($sp.Name) $($sp.Children.count) elements"
                    $elements += $sp.Children
                    $newcheck += $sp.Children
                }
                "GroupBox" {
                    #Write-Log "Adding $($sp.Name) ($($sp.gettype().Name)) 1 element"
                    $elements += $sp.Content
                    $newcheck += $sp.Content

                    Enable-CollapsibleElement $sp
                }
                default {
                    #Write-Log "Adding $($sp.Name) ($($sp.gettype().Name)) no content"
                }
            } # switch
        }
        $tocheck = @($newcheck)
    }

    foreach($element in $elements) {
        if($element.Name -like "*_*") {
            switch (($element.Name -split "_")[0]) {
                "cb" { # CheckBox
                        $element.IsChecked = $script:Settings.(($element.Name -split "_")[1])
                        if(!$script:settingsInitialized) {
                            #Write-Log "Adding events to $($element.Name)"
                            $element.Add_Checked({
                                $script:Settings.(($This.Name -split "_")[1]) = $This.IsChecked
                                $script:unsavedSettings = $true
                                Update-UIFromSetting
                            })
                            $element.Add_Unchecked({
                                $script:Settings.(($This.Name -split "_")[1]) = $This.IsChecked
                                $script:unsavedSettings = $true
                                Update-UIFromSetting
                            })

                        }
                    }
                "tb" { # TextBox
                        $element.Text = $script:Settings.(($element.Name -split "_")[1])
                        if(!$script:settingsInitialized) {
                            #Write-Log "Adding events to $($element.Name)"
                            $element.Add_GotFocus({
                                $this.SelectAll()
                            })
                            $element.Add_TextChanged({
                                $script:Settings.(($This.Name -split "_")[1]) = $This.Text
                                $script:unsavedSettings = $true
                            })
                        }
                    }
                "tbu" { # TextBox with special Update
                        $element.Text = $script:Settings.(($element.Name -split "_")[1])
                        if(!$script:settingsInitialized) {
                            # Add Event Handlers to the textbox
                            #Write-Log "Adding events to $($element.Name)"
                            $element.Add_GotFocus({
                                $this.Tag = $this.Text
                                $this.SelectAll()
                            })
                            $element.Add_LostFocus({
                                if($this.Text -ne $this.Tag) {
                                    $script:Settings.(($this.Name -split "_")[1]) = $This.Text
                                    $script:unsavedSettings = $true
                                    Update-UIFromSetting
                                }
                            })
                            $element.Add_PreviewKeyDown({
                                # update on Return, even if there is no change.
                                if($_.Key -eq [System.Windows.Input.Key]::Return) {
                                    $script:Settings.(($this.Name -split "_")[1]) = $This.Text
                                    Update-UIFromSetting
                                    if($this.Text -ne $this.Tag) {
                                        $this.Tag = $this.Text
                                        $script:unsavedSettings = $true
                                    }
                                }
                            })
                        }
                    }
                "" {} #Do nothing for nameless entries
                default {
                        Write-Log "Unhandled setting element $($element.name)"
                    }
            } # switch

            # update X and Y at the end, so size changes don't cause issues
            if($element.name -notlike "tbu_[XY]"){
                Update-UIFromSetting $element
            }
        } # if($element.Name -like "*_*"
    } # foreach($element

    # update X and Y now
    foreach($element in @($tbu_X,$tbu_Y)) {
        Update-UIFromSetting $element
    }
    $script:settingsInitialized = $true
} # Function Sync-Settings
$allowedCommands += 'Sync-Settings'

Function Set-ClipBoardText {
    Param(
        [string]$newtext,
        # No history prevents $newtext from entering history list
        [switch]$NoHistory
    )
    if($NoHistory) {$Script:CopiedText = $newtext}
    # suppress error messages for SetText()
    $oldErrorPref = $ErrorActionPreference
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
    [Windows.Clipboard]::SetText($newtext)
    $ErrorActionPreference = $oldErrorPref
    $CurrentClipBox.Text = $newtext
}
$allowedCommands += 'Set-ClipBoardText'

Function Test-CursorOutsideWindow {
    if($Window -and $Window.IsVisible) {
        $cursorPosition = [Windows.Forms.Cursor]::Position
        #convert screen position to logical position relative to $Window
        $cursorPosition = $Window.PointFromScreen((New-Object system.windows.point `
            -ArgumentList $cursorPosition.X,$cursorPosition.Y))
        $TopLeft = New-Object System.Windows.Point
        $BottomRight = (New-Object System.Windows.Point -ArgumentList $Frame.ActualWidth,$Frame.ActualHeight)
        ((($cursorPosition.X -lt $TopLeft.X) -or ($cursorPosition.X -gt $BottomRight.X)) -or 
            (($cursorPosition.Y -lt $TopLeft.Y) -or ($cursorPosition.Y -gt $BottomRight.Y)))
    } else {
        $false
    }
}
$allowedCommands += 'Test-CursorOutsideWindow'

Function Toggle-GroupVisibility {
    param($actionGroups=$null)
    #Write-log "Toggle-GroupVisibility $actionGroups"
    if(!$actionGroups.Count) {
        $actionGroups = $ActionBox.Children | ?{($_ -is [System.Windows.Controls.GroupBox]) -and ($_.Header -notmatch "^ClipTool")}
    }
    $visibility = "Visible"
    $return = $script:collapsibleLabel
    if(($actionGroups.Count -gt 0) -and ($actionGroups[0].Content.Visibility -match $visibility)) {
        $visibility = "Collapsed"
        $return = $script:expandableLabel
    }
    #Write-Log "toggling $($actionGroups.Length) groups to $visibility"
    $actionGroups | %{
        $_.Content.Visibility = $visibility
        $_.Header = $_.Header -replace $script:collapsibleSuffixes," $return"
    }
    $return
}
$allowedCommands += 'Toggle-GroupVisibility'

Function Update-ActionLockButton {
    if($cb_AllowActionDragDrop.IsChecked) {
        $ActionLockButton.Content = [char]::ConvertFromUtf32(0x1F511) # key
        $ActionLockButton.ToolTip = "Drag & drop allowed"
    } else {
        $ActionLockButton.Content = [char]::ConvertFromUtf32(0x1F512) # lock
        $ActionLockButton.ToolTip = "Drag & drop locked"
    }
}
$allowedCommands += 'Update-ActionLockButton'

Function Update-ClipDetails {
    if($ClipDetailsTab.Visibility -eq 'Visible') { # don't update if hidden
        $clipdata = [Windows.ClipBoard]::GetDataObject()
        $text = [Windows.Clipboard]::GetText()
        $img = [Windows.Clipboard]::GetImage()
        if($img) {
            $bytesPerPixel = [math]::Floor(($img.Format.BitsPerPixel + 7) / 8)
            $stride = 4 * [math]::Floor(($img.Width * $bytesPerPixel + 3) / 4)
            $pixels = [byte[]]::new($img.Width*$img.Height*$bytesPerPixel)
            $img.CopyPixels($pixels,$stride,0)
            $img = ([System.Text.Encoding]::ASCII.GetString($pixels)).GetHashCode()
        }
        $audio = [Windows.Clipboard]::GetAudioStream()
        $files = ([Windows.Clipboard]::GetFileDropList()) -join ", "
        $html = $clipdata.GetData('HTML Format')

        
        if(($script:lastdata.Text -ne $text) -or ($script:lastdata.Img -ne $img) -or ($script:lastdata.Audio -ne $audio) -or `
            ($script:lastdata.Files -ne $files) -or ($script:lastdata.HTML -ne $html)) {
                #Write-log 'no match. updating'
                $script:lastdata = New-Object psobject -ArgumentList @{HTML = $html; Text = $text; Img = $img; Audio = $audio; Files = $files;}
                
                $ClipDetailsBox.Children.Clear()
                $clipdata.GetFormats() | %{
                    #Write-Log "Format: $_"
                    $curritem = $null
                    try{
                        $curritem = $clipdata.GetData($_)
                    } catch {
                        $curritem = 'Bad clipboard data'
                    }
                    $group = New-Object System.Windows.Controls.GroupBox
                    $group.Header = "$_"
                    $scroll = New-Object System.Windows.Controls.ScrollViewer
                    $textbox = New-Object System.Windows.Controls.TextBox
                    $textbox.AcceptsReturn = $true
                    $textbox.IsReadOnly = $true
                    $textbox.Height = "NaN"
                    $textbox.MaxHeight = 200
                    $textbox.VerticalScrollBarVisibility = "Auto"
                    $textbox.TextWrapping = "Wrap"
                    if($curritem -ne $null) {
                        switch ($curritem.GetType()) {
                            'System.Drawing.Bitmap' {
                                $textbox.Text = "$_`n$($curritem.Width) x $($curritem.Height) pixels. $($curritem.PixelFormat) format."
                            }
                            'System.Windows.Interop.InteropBitmap' {
                                $textbox.Text = "$_`n$($curritem.PixelWidth) x $($curritem.PixelHeight) pixels. $($curritem.Format) format."
                            }
                            'System.IO.MemoryStream' {
                                    #$curritem.position = 0
                                    #$sr = [System.IO.StreamReader]::new($curritem)
                                    $textbox.FontFamily = 'Lucida Console'
                                    $textbox.HorizontalScrollBarVisibility = "Auto"
                                    $textbox.TextWrapping = "NoWrap"
                                    $textbox.Text = "$_`n$(Convert-BytesToHexView $curritem.ToArray() -max 320)"
                                    #$sr.Dispose()
                            }
                            default {
                                $textbox.Text = "$_`n$curritem"
                                #Write-log "default: '$curritem' - '$_'"
                            }
                        }
                    } else {
                        $textbox.Text = 'NULL'
                    }
                    $scroll.AddChild($textbox)
                    $group.AddChild($scroll)
                    $ClipDetailsBox.AddChild($group)
                    Enable-CollapsibleElement $group
                    #Toggle-GroupVisibility $group
                }
        }    
    }
} # End Function Update-ClipDetails
$allowedCommands += 'Update-ClipDetails'

Function Update-CollapseStatusButton {
    if(!($cb_CollapseOnMouseLeave.IsChecked)) {
        $CollapseStatusButton.Content = [char]::ConvertFromUtf32(0x2588) # full block
        $CollapseStatusButton.ToolTip = "Never Collapse Window"
    } else {
        if($cb_CollapseToTitle.IsChecked) {
            $CollapseStatusButton.Content = [char]::ConvertFromUtf32(0x2594) # upper one eigth block
            $CollapseStatusButton.ToolTip = "Collapse to Title"
        } else {
            $CollapseStatusButton.Content = [char]::ConvertFromUtf32(0x2580) # upper half block
            $CollapseStatusButton.ToolTip = "Collapse to ClipBox"
        }
    }
}
$allowedCommands += 'Update-CollapseStatusButton'


Function Update-HistoryStatus {
    $HistoryStatus.Text = "Entries: $($Script:HistoryCollection.count) - Size: $(($Script:HistoryCollection | measure-object -property Length -sum | select -expandproperty sum) -as [int64])"
}
$allowedCommands += 'Update-HistoryStatus'



Function Update-PositionDisplay {
    if(!$script:isUpdatingPositionDisplay) {
        # prevents programatic corrections here from triggering more Updates
        $script:isUpdatingPositionDisplay = $true
        if($Window.WindowState -ne 'Maximized') {
            $Frame.Margin = "0"
            $MaxButton.Content = [char]::ConvertFromUtf32(0x1F5D6)
        } else { # it's maximized
            # Offset strange overlap in Windows 10
            $screen = Get-CurrentScreen
            if($screen) {
                $Frame.Margin = "$([Int32](($Window.ActualWidth-$screen.Bounds.Width)/2)-1),`
                    $([Int32](($Window.ActualHeight-$screen.Bounds.Height)/2)-1)" 
            }
            #Write-Log "Maximized: screen = $screen; FrameMargin = $($Frame.Margin)"
            $MaxButton.Content = [char]::ConvertFromUtf32(0x1F5D7)
        }
        #Write-Log "Exiting Update-PositionDisplay: Window={Left=$($Window.Left),Top=$($Window.Top),Width=$($Window.Width),Height=$($Window.Height)}"
        $script:isUpdatingPositionDisplay = $false
    }
}
$allowedCommands += 'Update-PositionDisplay'

Function Update-SizeDisplay {
    if(!$script:overrideSizeDisplayUpdate -and ($Window.WindowState -eq 'Normal') -and !(Test-CursorOutsideWindow)) {
        $tbu_Width.text = $Window.Width
        $tbu_Height.text = $Window.Height
        $script:Settings.Width = $Window.Width
        $script:Settings.Height = $Window.Height
        #if($script:Settings.X -like "*r*") {Update-UIFromSetting $tbu_X}
    }
<#
    Write-Log "Update-SizeDisplay - Update: $($script:overrideSizeDisplayUpdate) - `
        Width = '$($window.Width)' - tb = '$($tbu_Width.Text)' - `
        Height = '$($window.Height)' - tb = '$($tbu_Height.Text)'"
#>
}
$allowedCommands += 'Update-SizeDisplay'

Function Update-TopStatusButton {
    if($cb_AlwaysOnTop.IsChecked) {
        $TopStatusButton.Content = "!"
        $TopStatusButton.ToolTip = "Always on Top"
    } else {
        if($cb_BringToFrontOnMouseEnter.IsChecked) {
            $TopStatusButton.Content = [char]::ConvertFromUtf32(0x1F441) # eye
            $TopStatusButton.ToolTip = "Bring to Front on Mouse Enter"
        } else {
            $TopStatusButton.Content = "-"
            $TopStatusButton.ToolTip = "Normal (other windows may occlude this window)"
        }
    }
}
$allowedCommands += 'Update-TopStatusButton'

Function Update-UIFromSetting {
    Param(
        $element = $this
    )
    switch($element.Name) {
        'cb_AllowActionDragDrop' {Update-ActionLockButton}
        'cb_AlwaysOnTop' {Update-TopStatusButton}
        'cb_CollapseOnMouseLeave'{Update-CollapseStatusButton}
        'cb_BringToFrontOnMouseEnter' {Update-TopStatusButton}
        'cb_CollapseToTitle' {Update-CollapseStatusButton}
        "cb_HideActionLabel" {
            if($element.IsChecked) {
                $ActionLabel.Visibility = "Collapsed"
            } else {
                $ActionLabel.Visibility = "Visible"
            }
        }
        "cb_HideClipDetails"  {
            if($element.IsChecked) {
                $ClipDetailsTab.Visibility = "Collapsed"
            } else {
                $ClipDetailsTab.Visibility = "Visible"
                Update-ClipDetails # in case details changed while it was hidden
            }
        }
        "cb_HideClipLabel" {
            if($element.IsChecked) {
                $ClipboardLabel.Visibility = "Collapsed"
            } else {
                $ClipboardLabel.Visibility = "Visible"
            }
        }
        "cb_HideLabels" {
            $visibility = "Visible"
            $fontsize = 12
            if($element.IsChecked) {
                $visibility = "Collapsed"
                $fontsize = 10
            }
            $ActionLabel.Visibility = $visibility
            $ClipboardLabel.Visibility = $visibility
<#
            foreach($child in $TitleBar.Children) {
                if($child -is [System.Windows.Controls.StackPanel]) {
                    foreach($grandchild in $child.Children) {
                        $grandchild.FontSize = $fontsize
                    }
                } else {
                    $child.FontSize = $fontsize
                }
            }
            $fontsize *= 1.5
            $TitleBar.Children[0].Children[0].FontSize = $fontsize
            #$TitleBar.TextElement.FontSize = 4*$fontmultiplier
            #$TitleBar.Children[0].TextElement.FontSize = 6*$fontmultiplier
#>
        }
        "cb_HideMenu" {
            if($element.IsChecked) {
                $MenuBar.Visibility = "Collapsed"
            } else {
                $MenuBar.Visibility = "Visible"
            }
        }
        "cb_HideSystemMessages" {
            if($element.IsChecked) {
                $SystemTab.Visibility = "Collapsed"
            } else {
                $SystemTab.Visibility = "Visible"
            }
        }
        "cb_HideTemplateFields"  {
            if($element.IsChecked) {
                $FieldsTab.Visibility = "Collapsed"
            } else {
                $FieldsTab.Visibility = "Visible"
            }
        }
        "cb_HideTitleStatus" {
            if($element.IsChecked) {
                $TitleStatus.Visibility = "Collapsed"
            } else {
                $TitleStatus.Visibility = "Visible"
            }
        }
        "tbu_ActionWidth" {
            $ActionColumn.Width = $script:Settings.ActionWidth
        }
        "tbu_ClipHeight" {
            $ClipGridRow.Height = $script:Settings.ClipHeight
        }
        "tbu_Height" {
            $Window.Height = $script:Settings.Height
        }
        "tbu_Width" {
            $Window.Width = $script:Settings.Width
        }
        "tbu_WindowBackground" {
            $Window.Background = $script:Settings.WindowBackground
        }
        "tbu_X" {
            $screen = $null
            $newX = $null
            $screenselected = $false
            if($script:Settings.X -like "*:*") {
                $screen = ([System.Windows.Forms.Screen]::AllScreens | select DeviceName,Primary,Bounds,WorkingArea,`
                        @{name="position";expression={[double]"$($_.Bounds.X).$($_.Bounds.Y)"}} | `
                        sort -Property position)[($script:Settings.X -split ":")[0]-1]
                $screenselected = $true
            }
            if(!$screen) {$screen = Get-CurrentScreen}
            switch (($script:Settings.X -split ":")[-1]) {
                {$_ -like "c*"} {
                    $newX = $screen.WorkingArea.X + [int]($screen.WorkingArea.Width-$window.Width)/2
                }
                {$_ -like "l*"} {
                    $newX = $screen.WorkingArea.X
                }
                {$_ -like "r*"} {
                    $newX = $screen.WorkingArea.X + $screen.WorkingArea.Width - $Window.Width
                }
                default {
                    if($_ -ge 0) {
                        if($screenselected) {
                            $newX = $screen.WorkingArea.X + $_
                        } else {
                            $newX = $_
                        }
                    }
                }
            }
            if($newX -ne $null) {
                if($screenselected -and ($screen.WorkingArea.Width -gt $Window.Width)) {
                    $Window.Left =  [System.Math]::Max($screen.WorkingArea.X,[System.Math]::Min($newX,$screen.WorkingArea.X+$screen.WorkingArea.Width-$Window.Width))
                } else {
                    $Window.Left = $newX
                }
            }
            #Write-log "X updated screen $screen"
        } # tbu_X
        "tbu_Y" {
            switch ($script:Settings.Y) {
                {$_ -like "b*"} {
                    $screen = Get-CurrentScreen
                    $Window.Top = $screen.WorkingArea.Y + $screen.WorkingArea.Height - $Window.Height
                }
                {$_ -like "c*"} {
                    $screen = Get-CurrentScreen
                    $Window.Top = $screen.WorkingArea.Y + [int]($screen.WorkingArea.Height-$Window.Height)/2
                }
                {$_ -like "t*"} {
                    $screen = Get-CurrentScreen
                    $Window.Top = $screen.WorkingArea.Y
                }
                default {
                    if($script:Settings.Y -ge 0) {$Window.Top = $script:Settings.Y}
                }
            }
        }
        #the following left blank on purpose to prevents the default action. no further action required
        'cb_CopyHistoryOnClick' {}
        'cb_MetaCopy' {}
        'cb_DebugToConsole' {}
        'cb_DebugToFile' {}
        'tbu_OpacityOnMouseEnter' {}
        'tbu_OpacityOnMouseLeave' {}
        'tbu_Delimiter' {}
        'tbu_CollapseDelay' {}
        'tbu_SplitterSize' {}
        default {
            Write-Log "Unhandled control: $($element.Name)" -priority 3 -category "warning"
        }
    }
} # Function Update-UIFromSetting
$allowedCommands += 'Update-UIFromSetting'

Function Write-Log {
    Param (
        [string]$text,
        [int]$priority = 5,
        [string]$category = "debug"
    )
    $timestamp = (Get-Date -Format "yyMMdd HH:mm:ss")
    [void]$Script:SystemCollection.Add("[$timestamp] $text")
    if($script:Settings.DebugToConsole) {
        switch($category) {
            'error' {<# do nothing. already seen in console #>}
            'warning' {Write-Warning "[$timestamp] $text"}
            default {Write-Host "[$timestamp] $text"}
        }
    }
    if($script:Settings.DebugToFile) {
        $path = Join-Path $script:localpath "log"
        if(!(Test-Path $path)) {New-Item -ItemType directory -Path $path}
        $obj = New-Object psobject
        $obj | Add-Member timestamp $timestamp
        $obj | Add-Member priority $priority
        $obj | Add-Member category $category
        $obj | Add-Member text $text
        $obj | Export-Csv (Join-Path $path $script:logfilename) -NoTypeInformation -Append
    }
}
$allowedCommands += 'Write-Log'

# Template Functions

Function Apply-Template {
    # parses $text for template keys marked with [key], replaces them with the template value for key, and returns the transformed text. 
    param($text)
    $filter = "\[(.*?)\]"
    [Regex]::new($filter).Matches($text) | %{$_.Groups[1].Value} | select -Unique | %{
        $field = Get-TemplateField $_
        if($field) {$text = ($text -replace "\[$_\]",$field.Value)}
    }
    $text
} # function Apply-Template
$allowedCommands += "Apply-Template"

Function Clear-Template {
    $script:TemplateFields.Clear()
    $script:TemplateFields.Add([pscustomobject]@{Name='';Value='';Comments=''})
} # function Clear-Template
$allowedCommands += "Clear-Template"

Function ConvertTo-Template {
    Param(
        [string]$text
    )
    Edit-Action (Add-ActionButton @{
        name='Template'
        group='Favorites'
        description="Apply Template: $text"
        script="`$text=`"$([System.Web.HttpUtility]::HtmlEncode($text))`";`$script:CopiedText=[System.Web.HttpUtility]::HtmlDecode(`$text);Set-ClipBoardText (Apply-Template `$script:CopiedText)"
    })
} # function ConvertTo-Template
$allowedCommands += "ConvertTo-Template"

Function Export-Template {
    # TODO:
} # function Export-Template
$allowedCommands += "Export-Template"

Function Get-TemplateField {
    param(
        $name
    )
    $script:TemplateFields | ?{$_.name -eq $name} 
} # function Get-TemplateField
$allowedCommands += "Get-TemplateField"

Function Get-TemplateValue {
    param(
        $name
    )
    $script:TemplateFields | ?{$_.name -eq $name} | select -ExpandProperty Value
} # function Get-TemplateValue
$allowedCommands += "Get-TemplateValue"

Function Import-Template {
    # TODO:
} # function Import-Template
$allowedCommands += "Import-Template"

Function Initialize-TemplateValue {
    param(
        $name = '',
        $value = '',
        $comments = ''
    )
    $field = Get-TemplateField $name
    if(!$field) {
        $script:TemplateFields.Add([pscustomobject]@{Name=$name;Value=$value;Comments=$comments})
        $field = $value
    }
    $field
} # function Initialize-TemplateValue
$allowedCommands += "Initialize-TemplateValue"

Function Read-TemplateValues {
<# parses each line of $text. If $delimiter is found on a line, it is translated to a Template Field. 
    The left side becomes the Name and the right side becomes the Value. #>
    Param(
        # Text to parse for template field values
        [string]$text,

        <# Regex Delimiter used to split each line into name/value pairs. Default is to split on any colon (:), 
            equal sign (=) or tab character. #>
        [string]$delimiter="[:=\t]",

        # Automatically trim whitespace around the Name, Value, None, or Both. Default: Both
        [ValidateSet('None','Name','Value','Both')]
        [string]$trim = 'Both'
    )
    $n = 0
    foreach($line in ($text -split "`r`n|`n|`r")) {
        $name,$value = $line -split $delimiter,2
        if($value -ne $null) {
            switch -Wildcard ($trim) {
                "b*" {
                    $name = $name.Trim()
                    $value = $value.Trim()
                }
                "na*" {$name = $name.Trim()}
                "v*" {$value = $value.Trim()}
            }
        }
        if($name) {
            $n++
            Set-TemplateValue -name $name -value $value
        }
    }
    Write-Log "Read-TemplateValues parsed $n Name/Value pairs."
} # function Read-TemplateValues
$allowedCommands += "Read-TemplateValues"

Function Set-TemplateValue {
    param(
        $name,
        $value = $null,
        $comments = $null
    )
    $field = Get-TemplateField $name
    if($field) {
        $update = $false
        if($value -ne $null) {
            $field.Value = $value
            $update = $true
        }
        if($comments -ne $null) {
            $field.Comments = $comments
            $update = $true
        }
        if($update) {$datagrid.Items.Refresh()}
    } else {
        Initialize-TemplateValue -name $name -value $value -comments $comments
    }
} # function Set-TemplateValue
$allowedCommands += "Set-TemplateValue"

# End New Functions

# Control Functionality
$AcceptEditActionButton.Add_Click({
    Apply-EditAction
    $script:editAction = $null
    $editActionTab.Visibility = "Collapsed"
    if($TabControl.SelectedItem -eq $EditActionTab) {$TabControl.SelectedItem = $HistoryTab}
})

$ActionDivider.Add_DragCompleted({
    $tbu_ActionWidth.text = $ActionColumn.Width
    $script:Settings.ActionWidth = $tbu_ActionWidth.text
})

$ActionLockButton.Add_Click({
    $cb_AllowActionDragDrop.IsChecked = !($cb_AllowActionDragDrop.IsChecked)
    Update-ActionLockButton
})

$ApplyEditActionButton.Add_Click({
    Apply-EditAction
})

$Clear_Menu.Add_Click({
    Confirm-MenuHidden
    Clear-Viewer
})

$ClearHistory_Menu.Add_Click({
    [void]$Script:HistoryCollection.Clear()
    Update-HistoryStatus
})

$ClipTrim.Add_Click({
    Set-ClipBoardText ($CurrentClipBox.Text.Trim())
})

$CloseButton.Add_Click({
    $Window.Close()
})

$CloseEditActionButton.Add_Click({
    $script:editAction = $null
    $editActionTab.Visibility = "Collapsed"
    if($TabControl.SelectedItem -eq $EditActionTab) {$TabControl.SelectedItem = $HistoryTab}
})

$CollapseStatusButton.Add_Click({
    if(!($cb_CollapseOnMouseLeave.IsChecked)) {
        $cb_CollapseOnMouseLeave.IsChecked = $true
        $cb_CollapseToTitle.IsChecked = $true
    } else {
        if($cb_CollapseToTitle.IsChecked) {
            $cb_CollapseToTitle.IsChecked = $false
        } else {
            $cb_CollapseOnMouseLeave.IsChecked = $false
        }
    }
    Update-CollapseStatusButton
})

$Copy_Menu.Add_Click({
    Confirm-MenuHidden
    Set-ClipBoardText @"
$($HistoryBox.SelectedItems -join "`n")
"@ -NoHistory
})

$CopyEditActionButton.Add_Click({
    if($tbact_Content.Text -eq $script:editAction.Content) {
        $tbact_Content.Text = "Copy of $($tbact_Content.Text)"
    }
    $script:editAction = Add-ActionButton @{name=$tbact_Content.Text;group=$tbact_Group.Text}
    Apply-EditAction
})

$CurrentClipBox.Add_GotFocus({
    $this.Tag = $this.Text
})

$CurrentClipBox.Add_LostFocus({
    if($this.Text -ne $this.Tag) {
        Set-ClipBoardText $this.Text
    }
    $this.Tag = $null
})

$CurrentClipBox.Add_TextChanged({
    $counts=($CurrentClipBox.Text | Measure-Object -Line -Word -Character)
    $ClipStatus.Content = " Lines: $($counts.lines)  Words: $($counts.words)  Characters: $($counts.characters) "
    if($CurrentClipBox.Text -match "^\s|\s$") {
        $ClipTrim.Content = ' __ '
        $ClipTrim.ToolTip = 'Clip has leading or trailing whitespace. Click here to trim it.'
        $ClipTrim.Background = "#1F00"
    } else {
        $ClipTrim.Content = [char]::ConvertFromUtf32(0x23B5) # unicode bottom square bracket
        $ClipTrim.ToolTip = 'Clip has NO leading or trailing whitespace.'
        $ClipTrim.Background = "#0FFF"
    }

})

<#
$datagrid.Add_BeginningEdit({
    param(
        $source,
        [System.Windows.Controls.DataGridBeginningEditEventArgs]$event
    )
    Write-Log "BeginningEdit $($event.cancel) - ($($event.column),$($event.row))"
    Write-Log "`tHeader - '$($event.column.Header)'"
    Write-Log "`tItem - '$($event.row.Item)'"

})
#>

$Datagrid.Add_CellEditEnding({
    param(
        $source,
        $event
    )
<#
    Write-Log "CellEditEnding $($event.cancel) - ($($event.column),$($event.row))"
    Write-Log "`tHeader - '$($event.column.Header)'"
    Write-Log "`tItem - '$($event.row.Item)'"
    Write-Log "`tEditAction - '$($event.EditAction)'"
    Write-Log "`tEditingElement.Text - '$($event.EditingElement.Text)'"
#>
    if(($event.column.Header -eq 'Name') -and (($event.EditingElement.Text -eq '') -or ($event.row.Item.Name -ne $event.EditingElement.Text))) {
        if(Get-TemplateField $event.EditingElement.Text) {
            #Write-Log "Abort change! Changed to an existing name."
            $event.EditingElement.Text = $event.row.Item.Name
        } elseif($event.row.Item.Name -eq '') { # blank name, make a new blank field at the end
            #Write-Log "New Blank Entry"
            $script:TemplateFields.Add([pscustomobject]@{Name='';Value='';Comments=''})
        }
    }
})

$dgcm_ClearAll.Add_Click({Clear-Template})

$dgcm_Filter.Add_Click({
    if($dgfilter.Visibility -eq "Collapsed"){
        $dgfilter.Visibility = "Visible"
        $this.IsChecked = $true
    } else {
        $dgfilter.Visibility = "Collapsed"
        $this.IsChecked = $false
    }
})

$dgcm_RemoveSelected.Add_Click({
    @($Datagrid.SelectedItems) | ForEach {
        #Write-Log "Selected: $_ "
        [void]$script:TemplateFields.Remove($_)
    }
})

$dgcm_ReplaceSelectedPlain.Add_Click({
    $working = $CurrentClipBox.Text
    @($Datagrid.SelectedItems) | ForEach {
        #Write-Log "Selected: $_ "
        $working = ($working -replace [regex]::Escape($_.Name),$_.Value)
    }
    Set-ClipBoardText $working
})

$dgcm_ReplaceSelectedRegEx.Add_Click({
    $working = $CurrentClipBox.Text
    @($Datagrid.SelectedItems) | ForEach {
        #Write-Log "Selected: $_ "
        $working = ($working -replace $_.Name,$_.Value)
    }
    Set-ClipBoardText $working
})

$dgf_Comments.Add_TextChanged({Apply-TemplateFieldFilters $this})

$dgf_Name.Add_TextChanged({Apply-TemplateFieldFilters $this})

$dgf_Value.Add_TextChanged({Apply-TemplateFieldFilters $this})

$ExitWithoutSave_Menu.Add_Click({
	$script:unsavedSettings = $false
	$Window.Close()
})

$Favorite_Menu.Add_Click({
    Confirm-MenuHidden
    Add-Favorite $CurrentClipBox.text
})

$FavoriteHistory_Menu.Add_Click({
    Add-Favorite @"
$($HistoryBox.SelectedItems | Out-String)
"@ -replace "\n$",''
})

$HistoryBox.Add_MouseLeftButtonUp({
    if($script:Settings.CopyHistoryOnClick -and ($HistoryBox.SelectedItems.Count -eq 1)) {
        Set-ClipBoardText ($HistoryBox.SelectedItems) -NoHistory
    }
})

$HistoryBox.Add_MouseRightButtonUp({
    If ($Script:HistoryCollection.Count -gt 0) {
        $Remove_Menu.IsEnabled = $True
        $Copy_Menu.IsEnabled = $True
    } Else {
        $Remove_Menu.IsEnabled = $False
        $Copy_Menu.IsEnabled = $False
    }
})

$HistoryFilterBox.Add_TextChanged({
    [System.Windows.Data.CollectionViewSource]::GetDefaultView($HistoryBox.ItemsSource).Filter = [Predicate[Object]]{
        Try {
            $args[0] -match [regex]::Escape($HistoryFilterBox.Text)
        } Catch {
            $True
        }
    }    
}) # $HistoryFilterBox.Add_TextChanged

$JoinHistory_Menu.Add_Click({
    Set-ClipBoardText $($HistoryBox.SelectedItems -join $script:Settings.Delimiter)
})

$LoadAction_Menu.Add_Click({
    Confirm-MenuHidden
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Open GregsClipTool Action File"
    $OpenFileDialog.initialDirectory = $script:localpath
    if( Test-Path (Join-Path $script:localpath 'actions') ) {
        $OpenFileDialog.initialDirectory = (Join-Path $script:localpath 'actions')
    }
    $OpenFileDialog.filter = "Valid formats (*.json;*.ps1)|*.json;*.ps1|JSON format (*.json)|*.json|PowerShell format (*.ps1)|*.ps1"
    if($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Log "File selected: $($OpenFileDialog.FileName)"
        Load-Actions $OpenFileDialog.FileName
    }
})

$Lowercase_Menu.Add_Click({
    Confirm-MenuHidden
	Set-ClipBoardText($CurrentClipBox.text).ToLower()
})

$MaxButton.Add_Click({
    $script:overrideSizeDisplayUpdate = $true
    if($Window.WindowState -eq 'Maximized') {
        $Window.WindowState = 'Normal';
    } else {
        $Window.WindowState = 'Maximized';
    }
    $script:overrideSizeDisplayUpdate = $false
})

#$MenuBar.Add_LostKeyboardFocus({Confirm-MenuHidden})

$MinButton.Add_Click({
    $script:overrideSizeDisplayUpdate = $true
    $Window.WindowState = 'Minimized';
    $script:overrideSizeDisplayUpdate = $false
})

$MoveDownEditActionButton.Add_Click({
    Move-Element -Element $script:editAction -target 'down' -Container $script:editAction.parent
})

$MoveSelected_Menu.Add_Click({
    @($HistoryBox.SelectedItems) | ForEach {
        Add-History $_
    }
    $HistoryBox.Parent.ScrollToBottom()
})

$MoveUpEditActionButton.Add_Click({
    Move-Element -Element $script:editAction -target 'up' -Container $script:editAction.parent
})

$NewAction_Menu.Add_Click({
    Confirm-MenuHidden
    New-ActionButton
})

$ParseValues_Menu.Add_Click({
    Confirm-MenuHidden
    Read-TemplateValues $CurrentClipBox.text $script:Settings.Delimiter
})

$Remove_Menu.Add_Click({
    @($HistoryBox.SelectedItems) | ForEach {
        while($Script:HistoryCollection -ccontains $_) {[void]$Script:HistoryCollection.Remove($_)}
    }
    Update-HistoryStatus
})

$ReturnDock_Menu.Add_Click({
    Confirm-MenuHidden
    Update-UIFromSetting $tbu_X
    Update-UIFromSetting $tbu_Y
})

$SaveAction_Menu.Add_Click({
    Confirm-MenuHidden
    Save-Actions
})

$SaveSettings_Menu.Add_Click({
    Confirm-MenuHidden
    Save-Settings
})

$Sanitize_Menu.Add_Click({
    Confirm-MenuHidden
	Set-ClipBoardText($CurrentClipBox.text)
})

$SplitDelim_Menu.Add_Click({
    Confirm-MenuHidden
	foreach($part in ($CurrentClipBox.text -split $script:Settings.Delimiter)) {
		Add-History $part
	}
})

$SplitLines_Menu.Add_Click({
    Confirm-MenuHidden
	foreach($line in ($CurrentClipBox.text -split "`r`n|`n|`r")) {
		Add-History $line
	}
})

$SystemFilterBox.Add_TextChanged({
    [System.Windows.Data.CollectionViewSource]::GetDefaultView($SystemBox.ItemsSource).Filter = [Predicate[Object]]{
        Try {
            $args[0] -match [regex]::Escape($SystemFilterBox.Text)
        } Catch {
            $True
        }
    }    
}) # $SystemFilterBox.Add_TextChanged

$Template_Menu.Add_Click({
    Confirm-MenuHidden
    ConvertTo-Template $CurrentClipBox.text
})

$TitleBar.Add_MouseDown({
    if($Window.WindowState -eq 'Maximized') {
        $Window.WindowState = 'Normal';
        #$MaxButton.Content = [char]::ConvertFromUtf32(0x1F5D6)

        $cursorPosition = [Windows.Forms.Cursor]::Position
        #$visualSize = $Window.PointFromScreen((New-Object system.windows.point -ArgumentList $Window.Width,$Window.Height))
        $Window.Left = $cursorPosition.X - [int]($Window.Width/2)
        $Window.Top = 0
    }
    $Window.DragMove()
})

$TitleCase_Menu.Add_Click({
    Confirm-MenuHidden
	Set-ClipBoardText((Get-Culture).TextInfo.ToTitleCase(($CurrentClipBox.text).ToLower()))
})

$ToolBoxDivider.Add_DragCompleted({
    $tbu_ClipHeight.text = $ClipGridRow.Height
    $script:Settings.ClipHeight = $ClipGridRow.Height
})

$TopStatusButton.Add_Click({
    if($cb_AlwaysOnTop.IsChecked) {
        $cb_AlwaysOnTop.IsChecked = $false
        $cb_BringToFrontOnMouseEnter.IsChecked = $true
    } else {
        if($cb_BringToFrontOnMouseEnter.IsChecked) {
            $cb_BringToFrontOnMouseEnter.IsChecked = $false
        } else {
            $cb_AlwaysOnTop.IsChecked = $true
        }
    }
    Update-TopStatusButton
})

$Trim_Menu.Add_Click({
    Confirm-MenuHidden
	Set-ClipBoardText($CurrentClipBox.text).Trim()
})

$Uppercase_Menu.Add_Click({
    Confirm-MenuHidden
	Set-ClipBoardText($CurrentClipBox.text).ToUpper()
})

$Window.Add_Closed({
    $Script:timer.Stop()
    $Script:HistoryCollection.Clear()
    $Script:SystemCollection.Clear()
    $Script:TemplateFields.Clear()
    if($script:unsavedSettings) {Save-Settings}
    if($Runspacehash -and $Runspacehash.PowerShell) {
        Write-Log "Disposing runspace PowerShell instance."
        $Runspacehash.PowerShell.Dispose()
    }
}) #Window.Add_Closed

$Window.Add_Deactivated({
    #Write-Log "Window lost focus - '$($CurrentClipBox.Text)'; '$($CurrentClipBox.Tag)'"
    if($CurrentClipBox.Tag -and ($CurrentClipBox.Text -ne $CurrentClipBox.Tag)) {
        #Write-Log "Updating clipboard"
        # editted current clip, so update clipboard
        Set-ClipBoardText $CurrentClipBox.Text
    }
})

$Window.Add_LocationChanged({Update-PositionDisplay})

$Window.Add_MouseEnter({
    $script:collapseTime = $null
    $script:targetHeight = $null
    $Window.Opacity = $script:Settings.OpacityOnMouseEnter
    $script:overrideSizeDisplayUpdate = $true
    $Window.Width = $script:Settings.Width
    $Window.Height = $script:Settings.Height
    $script:overrideSizeDisplayUpdate = $false
    # Write-Host "'$($Window.Width)'"
    if($script:Settings.BringToFrontOnMouseEnter -and !($Window.TopMost)) {
        $Window.topmost = $true
        $Window.topmost = $false
    }
    #$ToolBox.Visibility = 'Visible'
})

$Window.Add_MouseLeave({
    if(Test-CursorOutsideWindow) {
        Confirm-MenuHidden
        $Window.Opacity = $script:Settings.OpacityOnMouseLeave
        if($script:Settings.CollapseOnMouseLeave) {
            # collapseTime is checked in the primary timer loop
            $script:collapseTime = (Get-Date).AddSeconds($script:Settings.CollapseDelay)
        }
    }
    #Write-Log "Opacity: $($Window.Opacity)"
})

$Window.Add_PreviewKeyDown({
    #Write-Log "PreviewKeyDown: Keys: $($_.Key) - modifiers: ($($_.KeyboardDevice.Modifiers))"
    if($Runspacehash) {
        $Runspacehash.LastKeyEvent = $_
    }
    if(($_.KeyboardDevice.Modifiers -eq [System.Windows.Input.ModifierKeys]::Alt)) {
        if($_.Key -ne [System.Windows.Input.Key]::System) { # Alt + key always turns on the menu
            $MenuBar.Visibility = "Visible"
        } elseif($script:Settings.HideMenu) { # If HideMenu checked, alt without any other key makes the menu toggle visibility
            # only toggle visibility if Alt toggled. Prevents flashing menu if you hold Alt down
            # $_.IsToggled was unreliable, so check what the modifier was on last keypress
            if (!($script:previousModifierKey -band [System.Windows.Input.ModifierKeys]::Alt)) {
                if($MenuBar.Visibility -eq "Collapsed") {
                    $MenuBar.Visibility = "Visible"
                } else {
                    $MenuBar.Visibility = "Collapsed"
                }
            }
        }
    }
    $script:previousModifierKey = $_.KeyboardDevice.Modifiers
})

$Window.Add_PreviewKeyUp({
    #Write-Log "PreviewKeyUp: $($_.Key) ($($_.KeyboardDevice.Modifiers))"
    $script:previousModifierKey = $_.KeyboardDevice.Modifiers
})

$Window.Add_SizeChanged({Update-SizeDisplay})

$Window.Add_SourceInitialized({
    $Window.Title = "$appTitle $appVersion"

    #allow ToolTips to stay visible for 5 minutes
    $delay = New-Object -TypeName System.Windows.FrameworkPropertyMetadata -ArgumentList 300000
    [System.Windows.Controls.ToolTipService]::ShowDurationProperty.OverrideMetadata([System.Windows.DependencyObject], $delay)

    $Script:HistoryCollection = New-Object System.Collections.ObjectModel.ObservableCollection[string]
    $HistoryBox.ItemsSource = $Script:HistoryCollection

    $Script:SystemCollection = New-Object System.Collections.ObjectModel.ObservableCollection[string]
    $SystemBox.ItemsSource = $Script:SystemCollection

    $script:TemplateFields = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    $script:TemplateFields.Add([pscustomobject]@{Name='';Value='';Comments=''})
    $Datagrid.ItemsSource = $script:TemplateFields

    #Create Timer object
    $Script:timer = new-object System.Windows.Threading.DispatcherTimer 
    $timer.Interval = [TimeSpan]"0:0:.1" # 100 ms
    $script:ErrorCount = 0
    $timer.Add_Tick({
        Update-ClipDetails
        $text =  Get-ClipboardText
        if (($text.length -ne 0) -and ($script:Previous -cne $text -AND $script:CopiedText -cne $text)) {
            #Add to history
            Add-History $text
            $script:Previous = $text
            if(!($script:Settings.MetaCopy -and $CurrentClipBox.IsKeyboardFocused)) {
                $CurrentClipBox.Text = $text
            #} else {
            #    Write-Log "MetaCopy prevented clipbox update"
            }
        }
        if($script:collapseTime -and ((Get-Date) -gt $script:collapseTime)) {
            $script:collapseTime = $null
            #Write-Log "Collapsing - WindowState = $($Window.WindowState)"

            # Collapse the tool section
            if($Window.WindowState -eq 'Normal') {
                $script:overrideSizeDisplayUpdate = $true
                if($script:Settings.CollapseToTitle) {
                    $Window.Height = $TitleBar.ActualHeight
                    $Window.Width = $TitleLeft.ActualWidth
                    #if($script:Settings.X -like "*r*") {Update-UIFromSetting $tbu_X}
                } else {
                    # collapse to clipbox
                    $Window.Height = [int]($script:Settings.Height - $ToolBox.ActualHeight)
                    #$ToolBox.Visibility = "Hidden"
                }
                $script:overrideSizeDisplayUpdate = $false

    <#
                # Animate rollup
                if($script:targetHeight) {
                    # rollup window
                    $script:overrideSizeDisplayUpdate = $true
                    $Window.Height = $Window.Height - $script:heightDelta
                    if($Window.Height -lt $script:targetHeight) {
                        $script:collapseTime = $null
                        $script:targetHeight = $null
                    }
                    $script:overrideSizeDisplayUpdate = $false
        
                } else {
                    $script:targetHeight = $script:Settings.Height - $ToolBox.ActualHeight
                    $script:heightDelta = [math]::Ceiling($ToolBox.ActualHeight/4)
                }

    #>
            } # if($Window.WindowState -eq 'Normal')
        }
        if($Window.WindowState -ne $script:oldWindowState) {
            <# required because the Window LocationChanged event does not report 
                WindowState changes as advertised #>
            $script:oldWindowState = $Window.WindowState
            Update-PositionDisplay
        }
        if($Runspacehash -and ($script:ErrorCount -ne $Error.Count)) {
            # write new errors to the log
            for($i=$script:ErrorCount; $i -lt $error.Count; $i++) {
                Write-Log "Error $($i): $($Error[$i].Exception)`n`
                    $($Error[$i].InvocationInfo.PositionMessage)" -priority 1 -category "error"
            }
            $script:ErrorCount = $Error.Count
        }
    })
    $timer.Start()

    If (-NOT $timer.IsEnabled) {
        $Window.Close()
    }

    Load-Settings
    #$tb_delimstatus.Text = $tbu_delimiter.Text

    $defaultActionFile = Join-Path $script:localpath 'DefaultActions.json'
    if(Test-Path $defaultActionFile) {
        Load-Actions (Join-Path $script:localpath 'DefaultActions.json')
    } else {
        Write-Log "Default Actions file not found."
        Add-ActionButton (ConvertFrom-Json @'
[{"name":  "⭭","id":  "ab_8d83a2d09529233","group":  "ClipTool","color":  "#FDDD",
"description":  "Collapse or Expand All Action Groups","script":  "$this.Content=Toggle-GroupVisibility"},
{"name":  "Favorite","id":  "ab_8d83862f7a51068","group":  "ClipTool","color":  "#FDFD",
"description":  "Copy current clipboard to Favorites.","script":  "Add-Favorite $CurrentClipBox.text"},
{"name":  "_Clear All","id":  "ab_8d83862f7bd1d55","group":  "ClipTool","color":  "#FFDD",
"description":  "Clear current clipboard, history, template fields, and system messages.","script":  "Clear-Viewer"}]
'@ -ErrorAction SilentlyContinue)
    }
    Toggle-GroupVisibility
    Write-Log "Initialized in $($runningtime.ElapsedMilliseconds) ms"

    $tbu_delimiter.Text = ''
    $postShowTimer = new-object System.Windows.Threading.DispatcherTimer 
    $postShowTimer.Interval = [TimeSpan]"0:0:.1" # 100 ms
    $postShowTimer.Add_Tick({
        $tbu_delimiter.Text = $script:Settings.Delimiter
        $this.Stop()
    })
    $postShowTimer.Start()
}) # $Window.Add_SourceInitialized

Enable-CollapsibleElement $gbact_Desc
# End Control Functionality

if($Runspacehash) {
    $vars = @('Window','Settings','MenuBar','ActionBox')
    foreach($var in $vars) {
        $Runspacehash.$var = (Get-Variable $var).Value
    }
}

$Window.ShowDialog() | Out-Null

} else {
    Write-Warning "Window failed to open."
    Write-Host "Elapsed running time: $($runningtime.ElapsedMilliseconds) ms"
} # if($Window)

} # $ClipToolCoreScript

if($NoSeparateRunspace) { # command line option to run GregsClipTool app IN the PowerShell console
    if(!$psISE) {
        $Host.UI.RawUI.WindowTitle = "$appTitle - Console Window: DO NOT CLOSE until you are done with the tool"
    } else {
        # prevent ugly accidents when debugging
        Clear-variable Runspacehash -erroraction silentlycontinue
    }
    $hostlocalpath = Split-Path -Parent $MyInvocation.MyCommand.Path
    & $ClipToolCoreScript
    if(!$psISE) { # pause in console window so user may review messages
        $Host.UI.RawUI.WindowTitle = "$appTitle - Console Window: Program ended"
        Write-Host -NoNewLine 'Press any key to exit.'
        $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null
    }
} else {
    $Runspacehash=[hashtable]::Synchronized(@{})
    $Runspacehash.Host=$Host
    $Runspacehash.localpath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Runspacehash.runspace=[RunspaceFactory]::CreateRunspace()
    $Runspacehash.runspace.ApartmentState="STA"
    $Runspacehash.runspace.Open() 
    $Runspacehash.runspace.SessionStateProxy.SetVariable("Runspacehash",$Runspacehash)
    $Runspacehash.PowerShell={Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms}.GetPowerShell() 
    $Runspacehash.PowerShell.Runspace=$Runspacehash.runspace 
    $Runspacehash.Handle=$Runspacehash.PowerShell.AddScript($ClipToolCoreScript).BeginInvoke()
}

