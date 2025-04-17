# This script updates an SVG file from Signavio for use with Powerpoint as follows:
#   Prompts the user to select an SVG file from the Downloads folder.
#   Removes several regex patterns (unnecessary shapes) defined in $regexPatterns.
#   Processes all occurrences of a specific marker definition (with id="sid-[UUID]end") so that arrowheads scale properly when cropping and resizing the SVG
#   Remove redundant marker definitions from the <defs>-section (only different IDs, same shape) for filled and non-filled arrowheads
#   Update marker IDs in the file content below the <defs>-section
#   Overwrites the original file with the updated contents
#   Use an external SVG-Optimizer (SVGO, compiled windows-binary) to reduce the size of the file further

Write-Host "Dieses Skript bearbeitet SVG-Dateien aus Signavio, so dass die Dateien in Powerpoint verwendet werden koennen. `r`nBeliebige Taste druecken um eine SVG-Datei auszuwaehlen..."
[void][System.Console]::ReadKey($true)

# Load the Windows Forms assembly for the OpenFileDialog
Add-Type -AssemblyName System.Windows.Forms

# Create and configure the OpenFileDialog
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.InitialDirectory = "$env:USERPROFILE\Downloads"
$dialog.Filter = "SVG files (*.svg)|*.svg"
$dialog.Title = "Select an SVG File"

# Display the dialog and check if the user selected a file
if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No file selected. Exiting..."
    exit
}

# Retrieve the selected file path
$filePath = $dialog.FileName

# Verify that the file has a .svg extension
if ([System.IO.Path]::GetExtension($filePath).ToLower() -ne ".svg") {
    Write-Host "Selected file is not an SVG. Exiting..."
    exit
}

# Read the entire content of the file as a single string
$fileContent = Get-Content $filePath -Raw

# --- Step 1: Remove unwanted regex patterns ---

$regexPatterns = @(
    '<marker id="sid-[0-9a-fA-F-]{36}end_shadow"[\s\S]*?<\/marker>',
    '<marker id="sid-[0-9a-fA-F-]{36}start_shadow"[\s\S]*?\/>',
    '<marker id="sid-[0-9a-fA-F-]{36}start"[\s\S]*?\/>',
    'id="sid-[0-9a-fA-F-]{36}arrowhead"'
)

foreach ($pattern in $regexPatterns) {
    $fileContent = [regex]::Replace($fileContent, $pattern, '')
}

# --- Step 2: Process marker definitions for "end" markers of dashed lines---

# The pattern to match the complete marker definition with id="sid-[UUID]end"
# Captures the UUID in group 1.
$markerPattern = '<marker id="sid-([0-9a-fA-F-]{36})end"(?=[^>]*markerHeight="10")[^>]*>[\s\S]*?<path(?=[^>]*fill="none")[^>]*\/?>[\s\S]*?<\/marker>'

# Replace each matching marker with the new marker definition,
# while preserving the UUID.
$fileContent = [regex]::Replace($fileContent, $markerPattern, {
    param($match)
    # Capture the UUID from group 1
    $uuid = $match.Groups[1].Value

    # New marker definition
    return "<marker id=""sid-" + $uuid + "end"" markerHeight=""5"" markerUnits=""strokeWidth"" markerWidth=""5"" orient=""auto"" refX=""5"" refY=""2.5""> 
			<path d=""M 0 0 L 5 2.5 L 0 5"" fill=""none""  stroke=""#000000"" stroke-dasharray=""0"" /> 
    </marker>"
})

# --- Step 3: Process marker definitions for "end" markers of solid lines---

# The pattern to match the complete marker definition with id="sid-[UUID]end"
# Captures the UUID in group 1.
$markerPattern = '<marker id="sid-([0-9a-fA-F-]{36})end"(?=[^>]*markerHeight="16")[^>]*>[\s\S]*?<path(?=[^>]*fill="#000000")[^>]*\/?>[\s\S]*?<\/marker>'

# Replace each matching marker with the new marker definition,
# while preserving the UUID.
$fileContent = [regex]::Replace($fileContent, $markerPattern, {
    param($match)
    # Capture the UUID from group 1
    $uuid = $match.Groups[1].Value

    # New marker definition
    return "<marker id=""sid-" + $uuid + "end"" markerHeight=""7"" markerUnits=""strokeWidth"" markerWidth=""7"" orient=""auto"" refX=""6.8"" refY=""3"">
			<path d=""M 0 1 L 5 3 L 0 5z"" fill=""#000000"" stroke=""#000000"" stroke-width=""2"" /> 
    </marker>"
})

# --- 4. Find all arrowhead marker definitions and build a mapping ---
# We assume arrowhead markers have:
# - An opening <marker> tag with id="sid-<UUID>end", markerHeight=, etc.
# - An inner <path> tag that has a fill attribute.
# This regex uses a positive lookahead to require markerHeight= in the <marker> tag.
# It captures the UUID (group 1) and the fill attribute value (group 2).
$markerRegex = '<marker\s+id="(sid-[0-9a-fA-F-]{36})end"(?=[^>]*markerHeight=)[^>]*>[\s\S]*?<path[^>]*fill="([^"]+)"'

# Initialize a mapping hashtable: keys are original unique IDs, values are the standard IDs.
$mapping = @{}

# Get all matches
$matches = [regex]::Matches($fileContent, $markerRegex)
if ($matches.Count -eq 0) {
    Write-Host "No arrowhead markers matching the pattern were found."
} else {

    foreach ($match in $matches) {
        $oldID = $match.Groups[1].Value  # e.g. sid-d276da02-a830-4bf7-9c3f-9f86ce3878c8
        $fillValue = $match.Groups[2].Value
        if ($fillValue -eq "none") {
            $newID = "sid-standardArrowheadNonFilled"
        } else {
            $newID = "sid-standardArrowheadFilled"
        }
        # Store the mapping. (If multiple markers of the same type exist, they all map to the same standard ID.)
        $mapping[$oldID + "end"] = $newID
    }

    # --- 5. Remove the original arrowhead marker definitions from the content ---
    # We remove all markers that match our pattern.
    $fileContent = [regex]::Replace($fileContent, $markerRegex + '[\s\S]*?<\/marker>', '')

    # --- 6. Insert the two standard marker definitions into the defs section ---
    # Define standard marker definitions.
$standardNonFilled = @'
<marker id="sid-standardArrowheadNonFilled" markerHeight="5" markerUnits="strokeWidth" markerWidth="5" orient="auto" refX="5" refY="2.5">
	<path d="M 0 0 L 5 2.5 L 0 5" fill="none" stroke="#000000" stroke-dasharray="0" />
</marker>
'@

$standardFilled = @'
<marker id="sid-standardArrowheadFilled" markerHeight="7" markerUnits="strokeWidth" markerWidth="7" orient="auto" refX="6.8" refY="3">
	<path d="M 0 1 L 5 3 L 0 5z" fill="#000000" stroke="#000000" stroke-width="2" />
</marker>
'@

    # Insert the standard markers inside the <defs> section.
    # We assume there is a <defs> ... </defs> block. If not, we create one before </svg>.
    if ($fileContent -match '<defs[^>]*>') {
        # Insert right after the opening <defs> tag.
        $fileContent = $fileContent -replace '(<defs[^>]*>)', "`$1`n$standardNonFilled`n$standardFilled`n"
    } else {
        # No defs section found – create one before the closing </svg>
        $fileContent = $fileContent -replace '</svg>', "<defs>`n$standardNonFilled`n$standardFilled`n</defs>`n</svg>"
    }

    # --- 7. Replace all references to the old marker IDs with the standard ones ---
    # Old references (attributes like marker-start or marker-end) could appear anywhere in the file.
    foreach ($pair in $mapping.GetEnumerator()) {
        $old = $pair.Key
        $new = $pair.Value
        # Use regex escape on the old marker ID.
        $escaped = [regex]::Escape($old)
        $fileContent = [regex]::Replace($fileContent, $escaped, $new)
    }
}
Write-Host "Die Datei wurde ueberarbeitet und wird nun mit dem neuen Inhalt ueberschrieben. `r`nBeliebige Taste druecken um fortzufahren..."
[void][System.Console]::ReadKey($true)

# --- Overwrite the original file with the updated contents ---
Set-Content -Path $filePath -Value $fileContent

# ------------------------------------------------------------------------------------------------------------
# --- Now call external SVG Optimizer, available from https://github.com/Antonytm/svgo-executable/releases ---
# ------------------------------------------------------------------------------------------------------------

# Get the folder where the script is located.
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Build the full path to svgo-win.exe
$svgoPath = Join-Path $scriptFolder "svgo-win.exe"

# Check if svgo-win.exe exists in the script folder.
if (-not (Test-Path $svgoPath)) {
    Write-Error "svgo-win.exe nicht im gleichen Ordner wie dieses Script gefunden. Zusaetzliche SVG-Optimierung kann nicht erfolgen. `r`nDie auf Windows direkt ausfuehrbare Version des SVG Optimizer SVGO kann hier heruntergeladen werden: https://github.com/Antonytm/svgo-executable/releases"
    exit
}

# Run svgo-win.exe passing $filePath as an argument.
# The call operator (&) is used to execute the binary.
& $svgoPath $filePath

Write-Host "Zusaetzliche SVG-Optimierung erfolgt. `r`nBeliebige Taste druecken zum Beenden..."
[void][System.Console]::ReadKey($true)