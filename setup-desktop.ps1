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

# 1) Create desktop shortcut to the dashboard with the gavel icon
$lnkPath = Join-Path $desktop '\xEB\xB2\x95\xEB\xAC\xB4 \xEC\x98\xAC\xEC\x9D\xB8\xEC\x9B\x90.lnk'
$shell = New-Object -ComObject WScript.Shell
$sc = $shell.CreateShortcut($lnkPath)
$sc.TargetPath = $html
$sc.IconLocation = "$ico,0"
$sc.WorkingDirectory = $dir
$sc.Description = 'Law Firm All-in-One Dashboard'
$sc.Save()
Write-Host "Shortcut created on Desktop."

# 2) Set the wallpaper (centered/fill)
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'  # Fill
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper  -Value '0'

$code = @'
using System.Runtime.InteropServices;
public class Wp {
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
Add-Type $code
# SPI_SETDESKWALLPAPER = 20, SPIF_UPDATEINIFILE|SPIF_SENDCHANGE = 3
[Wp]::SystemParametersInfo(20, 0, $wallpaper, 3) | Out-Null
Write-Host "Wallpaper applied: $wallpaper"
Write-Host "Done. Check your Desktop."
