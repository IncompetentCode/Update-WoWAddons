# Check if we're running as admin
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{   
    Write-Host "Not running as administrator, re-launching as one..." -F Red
    Start-Sleep -Seconds 2
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Exit
}

# Global variables and settings
$ProgressPreference = 'SilentlyContinue'
$GamePath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft").InstallPath + "World of Warcraft Launcher.exe"
$AddonsFolderPath = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft").InstallPath + "Interface\Addons"

# Define AddOn class
class Addon
{
    [string]$Name
    [string]$Url
    [string]$Filter
    [string]$Check
    [int]$Interval

    Addon(
        [string]$n,
        [string]$u,
        [string]$f,
        [string]$c,
        [int]$i
    )
    {
        $this.Name = $n
        $this.Url = $u
        $this.Filter = $f
        $this.Check = $c
        $this.Interval = $i
    }
}

# Define function
function Update-Addons
{
    ([AddOn[]]$addons)

    foreach ($addon in $addons)
    {
        Write-Host

        # Skip if addon is new
        if (Test-Path ($AddonsFolderPath + $($addon.Check)))
        {
            $addonDate = (Get-Item ($AddonsFolderPath + $($addon.Check)) -ErrorAction SilentlyContinue).LastWriteTime
            if ($addonDate -gt [DateTime]::UtcNow.AddDays(-($addon.Interval)))
            {
                Write-Host "$($addon.Name) is less than $($addon.Interval) days old! Skipping..." -F Yellow
                continue
            }
        }

        Write-Host "Updating $($addon.Name) AddOn..." -F Yellow

        $fileName = ($env:temp + "\" + $($addon.Name) + ".zip")
        
        # Get real URL of CurseForge link
        #if ($addon.Url -like "*curseforge.com*") { $addon.Url = (Scrape-Url -Url $addon.Url) }

        Write-Host "Downloading $($addon.Name) from: $($addon.Url)" -F Magenta

        try 
        {
            Invoke-WebRequest $addon.Url -OutFile $fileName -ContentType application/octet-stream -TimeoutSec 3
            Write-Host "Successfully downloaded $($addon.Name)..."
        }
        catch
        {
            Write-Host "Could not download $($addon.Name) from $($addon.Url) ! Trying next addon..." -F Red
            continue
        }

        $addonFolders = (Get-ChildItem -Filter $addon.Filter ($AddonsFolderPath)).FullName

        if ($addonFolders.Length -gt 0) { Remove-Item ($addonFolders) -Force -Recurse }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fileName, $AddonsFolderPath)

        $addonDate = (Get-Item ($AddonsFolderPath + $($addon.Check)) ).LastWriteTime.ToShortDateString()

        if ($addonDate) { Write-Host "Updated $($addon.Name) to version $addonDate!" -ForegroundColor Green }
        else { Write-Host "Addon may not have updated properly..." -ForegroundColor Red }

        Remove-Item $fileName -Force
    }

    Write-Host "`nDone with updates!" -F Cyan
}

function Check-Danger
{
    if ($GamePath -eq $null -or $AddonsFolderPath -eq $null)
    {
        Write-Host "Nevermind! I'm missing information to do my job..." -F Red
    }
}

# For scraping URLs from CurseForge
function Scrape-Url
{
    Param([Parameter(Mandatory=$true)][string]$Url)
 
    $Html = Invoke-WebRequest -Uri $Url
    $Link = "https://www.curseforge.com" + ($Html.Links | Where InnerText -eq "here").href

    return $Link
}

# Define your addon list
$addons = New-Object 'System.Collections.Generic.List[Addon]'

$addons.Add([AddOn]::new("RaiderIO","https://wow.curseforge.com/projects/raiderio/files/latest","RaiderIO*","\RaiderIO\db\db_realms.lua",1))
$addons.Add([AddOn]::new("DBM","https://dev.deadlybossmods.com/download.php?id=1","DBM-*","\DBM-Core\dbm-core.lua",14))

# Start
Clear-Host
Write-Host "Hey handsome ;) Updating those addons for you~" -F Cyan


Update-Addons($addons) | Out-Null

Start-Sleep -Seconds 2

# Run the damn game
Start-Process $GamePath