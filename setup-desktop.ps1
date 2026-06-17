# Apply the sky-blue wallpaper and create a gavel-icon desktop shortcut to the dashboard.
# Usage: right-click > Run with PowerShell  (or run in a PowerShell window)

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $dir) { $dir = "C:\Users\icecake\all-in-one" }

$html      = Join-Path $dir 'index.html'
# Prefer the mascot assets when present (local PC); fall back to gavel (e.g. fresh clone from GitHub).
$icoMascot = Join-Path $dir 'mascot.ico'
$ico       = if (Test-Path $icoMascot) { $icoMascot } else { Join-Path $dir 'gavel.ico' }
$wpMascot  = Join-Path $dir 'wallpaper-mascot.png'
$wallpaper = if (Test-Path $wpMascot) { $wpMascot } else { Join-Path $dir 'wallpaper-skyblue.png' }
$desktop   = [Environment]::GetFolderPath('Desktop')

# 1) Create desktop shortcut to the dashboard (build the Korean name from code points to avoid encoding issues)
$name = -join ([char]0xBC95,[char]0xBB34,[char]0x20,[char]0xC62C,[char]0xC778,[char]0xC6D0)  # "법무 올인원"
$lnkPath = Join-Path $desktop ($name + '.lnk')
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnkPath)
$sc.TargetPath = $html
$sc.IconLocation = "$ico,0"
$sc.WorkingDirectory = $dir
$sc.Description = 'Law Firm All-in-One Dashboard'
$sc.Save()
Write-Host "Shortcut created on Desktop."

# 2) Wallpaper change is intentionally DISABLED (user prefers to keep their own desktop background).
#    To apply the included wallpaper manually: right-click the image > "Set as desktop background".
#    ($wallpaper still resolves to the chosen image if you want to re-enable this later.)
Write-Host "Done. Desktop shortcut created (wallpaper left unchanged)."
