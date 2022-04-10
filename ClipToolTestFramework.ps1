##########################################################################
# ClipTool Action Test Framework
##########################################################################
#
# This framework provides very simplified mirror functions to the 
# standard input and output provided in Greg's ClipTool, so developers
# can easily test simple actions in PowerShell IDEs.
#
# Enter your test code AFTER the "Action code starts here" line at the
# end of the file.
#
##########################################################################

# Create CurrentClipBox dummy obj with Text property
$CurrentClipBox = '' | select Text 
$CurrentClipBox.Text = Get-Clipboard

# optionally set $CurrentClipBox.Text to the exact string you want to test
#$CurrentClipBox.Text = 'https://alpha:beta@subsite.abc.com/sample/path/page.asp?query=b&param2=true'

# Send history entries straight to console
function Add-History([string]$text) {Write-Host $text}

# Send system log entries straight to console with "Log:" prefix
function Write-Log([string]$text) {Write-Host "Log: $text"}

# Sets $CurrentClipBox.Text and sends to console in warning text
function Set-ClipBoardText([string]$text) {
    $CurrentClipBox.Text = $text
    Write-Warning "CurrentClipBox.Text = '$($CurrentClipBox.Text)'"
}

Write-Warning "CurrentClipBox.Text = '$($CurrentClipBox.Text)'"
##########################################################################
# Action code starts here:
##########################################################################
