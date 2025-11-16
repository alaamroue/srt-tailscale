#Requires -RunAsAdministrator
<#
.SYNOPSIS
 Interactive USBIPD manager for attaching & detaching devices to WSL

.NOTES
 Press ↑/↓ arrows to navigate, Enter to select
#>

function Show-Menu {
    param(
        [string[]]$Options,
        [string]$Title,
        $Devices
    )

    $selected = 0

    while ($true) {
        Clear-Host
        Write-Host "`n=== $Title ===`n" -ForegroundColor Cyan

        if ($Devices) {
            Write-Host "Status is :" -ForegroundColor Yellow
            Write-Output $Devices
            Write-Host ""
        }

        for ($i = 0; $i -lt $Options.Length; $i++) {
            if ($i -eq $selected) {
                Write-Host "> $($Options[$i])" -ForegroundColor Green
            } else {
                Write-Host "  $($Options[$i])"
            }
        }

        $key = [console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { if ($selected -gt 0) { $selected-- } }
            'DownArrow' { if ($selected -lt $Options.Length-1) { $selected++ } }
            'Enter'     { return $Options[$selected] }
        }
    }
}

# Ensure usbipd installed
if (-not (Get-Command usbipd.exe -ErrorAction SilentlyContinue)) {
    Write-Host "usbipd-win missing. Installing..." -ForegroundColor Yellow
    winget install --interactive --exact dorssel.usbipd-win
}

function Get-UsbipdDevices {
    $raw = usbipd list
    $connected = $false
    $devices = @()

    foreach ($line in $raw -split "`n") {

        if ($line.Trim() -eq "Connected:") {
            $connected = $true
            continue
        }

        if ($line.Trim() -eq "Persisted:") { break }

        if ($connected -and $line -match '^\s*(?<BusID>\d+-\d+)\s+(?<VidPid>[0-9a-fA-F]{4}:[0-9a-fA-F]{4})\s+(?<Name>.+?)\s{2,}(?<State>Attached|Not shared|Shared)') {
            $devices += [PSCustomObject]@{
                BusID  = $matches['BusID']
                VidPid = $matches['VidPid']
                Name   = $matches['Name'].Trim()
                State  = $matches['State']
            }
        }
    }

    return $devices
}

# Get current devices status
$devices = Get-UsbipdDevices

# Main menu
$action = Show-Menu -Title "USBIPD for WSL — What would you like to do?" -Options @("Share and bind a device", "Detach a device",  "Unbind a device","Exit")

if ($action -eq "Exit") { exit }


function Make-DeviceOptions($devices, $filter) {
    $options = @()
    foreach ($dev in $devices | Where-Object { $_.State -match $filter }) {
        $options += "$($dev.BusID) | $($dev.VidPid) | $($dev.Name)"
    }
    $options += "⬅ Go back"
    $options += "Exit"
    return $options
}

if ($action -eq "Share and bind a device") {

    $selection = Make-DeviceOptions -devices $devices -filter "Not shared|Shared"

    if ($selection.Count -le 2) {
        Write-Host "`nNo bindable devices available." -ForegroundColor Red
        exit
    }

    $choice = Show-Menu -Title "Select device to share and bind to WSL" -Options $selection

    if ($choice -eq "⬅ Go back") { & $MyInvocation.MyCommand.Path; return }
    if ($choice -eq "Exit") { exit }

    $busid = $choice.Split('|')[0].Trim()

    Write-Host "`nBinding $busid..." -ForegroundColor Yellow
    usbipd bind --busid $busid

    Write-Host "Attaching to WSL..." -ForegroundColor Yellow
    usbipd attach --wsl --busid $busid

    Write-Host "`n🎉 Device successfully attached to WSL!" -ForegroundColor Green
}

if ($action -eq "Detach a device") {

    $selection = Make-DeviceOptions -devices $devices -filter "Attached"

    if ($selection.Count -le 2) {
        Write-Host "`nNo shared devices to detach." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path; return
    }

    $choice = Show-Menu -Title "Select device to detach from WSL" -Options $selection

    if ($choice -eq "⬅ Go back") { & $MyInvocation.MyCommand.Path; return }
    if ($choice -eq "Exit") { exit }

    $busid = $choice.Split('|')[0].Trim()

    Write-Host "`nDetaching $busid..." -ForegroundColor Yellow
    usbipd detach --busid $busid

    Write-Host "`n🔌 Device detached successfully!" -ForegroundColor Green
}

if ($action -eq "unbind a device") {

    $selection = Make-DeviceOptions -devices $devices -filter "^Shared$"

    if ($selection.Count -le 2) {
        Write-Host "`nNo shared devices to unbind." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path; return
    }

    $choice = Show-Menu -Title "Select device to unbind from WSL" -Options $selection

    if ($choice -eq "⬅ Go back") { & $MyInvocation.MyCommand.Path; return }
    if ($choice -eq "Exit") { exit }

    $busid = $choice.Split('|')[0].Trim()

    Write-Host "`nUnsharing $busid..." -ForegroundColor Yellow
    usbipd unbind --busid $busid

    Write-Host "`n🔌 Device unbinded successfully!" -ForegroundColor Green
}
