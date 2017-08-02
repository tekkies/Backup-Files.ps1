<#
.SYNOPSIS
    Backup files, preserving old file versions.
.DESCRIPTION
    Intended for backing up files to a set of external drives, keeping old versions of files and allowing the backups to be trimmed easily.  Timestamps are used to determine if a new copy of a file should be made.  If a new copy is made, the original is renamed to include a UTC timestamp in the name.
.NOTES
    If your destination runs out of space, use a tool like https://windirstat.net/ to prune it.
    Restore using RoboCopy flag "/xf *.tbhist*" to only restore the latest version of all files.
.PARAMETER Source
    The directory you want to backup.
.PARAMETER Destination
    The backup directory - this directory must already exist!
.PARAMETER Name
    The name of this backup set.
.PARAMETER Exclude
    Exclude patterns in REGEX form.
.PARAMETER WhatIf
    Don't do the actual backup - just report what would be backed up.
.PARAMETER Help
    Show this help.
.EXAMPLE
    PS C:\>Backup-Files.ps1 -source "C:\Dev\src" -destination "V:\src" -Name "Source Code" -exclude "\.exe$", "\\bin\\debug\\" -WhatIf


#>
param([string]$Source, [string]$Destination, [string]$Name="(unnamed)", [String[]] $Exclude, [switch] $WhatIf, [switch]$Help)


if (($source -eq '') -or ($help.IsPresent)) {
    Get-Help $PSCommandPath -Detailed
    exit
}

Set-StrictMode -Version 4.0 #https://blogs.technet.microsoft.com/pstips/2014/06/17/powershell-scripting-best-practices/
$ErrorActionPreference = "Stop";


function Print-Object($object) {
    $object | ConvertTo-Json | Write-Host
}


function Assert-Exists($path, $shouldExist) {
    if( (Test-Path $path ) -ne $shouldExist ) {
        Write-Error -Message "Path $path $(if($shouldExist) {"should"} else {"should not"} ) exist" -ErrorAction Stop
    }
}

function Filter-Files($files, $exclusions) {
    if($files -ne $null) {
        foreach ($exclude in $exclusions) {
            $files = ($files | where { $_.FullName -Notmatch $exclude })
        }
        $files
    }
}

function IsSourceNewer($sourceFile, $existingFile) {
    $isNewer = $false
    $span = New-TimeSpan $existingFile.LastWriteTimeUtc $sourceFile.LastWriteTimeUtc
    if($span.TotalSeconds -gt 2) { #FAT time resolution
        $isNewer = $true
    }
    return $isNewer
}

function Rename-DestinationFile ($job, $existingFile) {
    $destinationFile = Join-Path $existingFile.Directory ($existingFile.BaseName + ".tbhist." + $existingFile.LastWriteTimeUtc.ToString("yyyyMMdd-HHmmss") + $existingFile.Extension)
    Move-Item $existingFile $destinationFile
}


function Copy-File($sourceFile, $destinationPath) {
    if($whatIf.IsPresent) {
        Write-Host "   WhatIf: $($sourceFile.FullName)"
    } else {
        Write-Host " $($sourceFile.FullName)"
        Copy-Item -LiteralPath $sourceFile.FullName $destinationPath
    }
    $script:result.Copied.Add($destinationPath)
}


function Get-DestinationPath($job, $sourceFile) {
    $tail = ($sourceFile.FullName.Replace($job.Source,"")).TrimStart("\")
    Join-Path $job.Destination $tail
}

function Backup-File($job, $sourceFile) {
    $destinationPath = Get-DestinationPath $job $sourceFile
    if (Test-Path -LiteralPath $destinationPath) {
        $existingFile = Get-Item -LiteralPath $destinationPath
        if (IsSourceNewer $sourceFile $existingFile) {
            if(!$whatIf.IsPresent) {
                Rename-DestinationFile $job $existingFile  
            }
            Copy-File $sourceFile $destinationPath          
        }
    } else {
        $destinationFolder = Split-Path -Parent $destinationPath
        if(!$whatIf.IsPresent) {
            New-Item $destinationFolder -type directory -Force
        }
        Copy-File $sourceFile $destinationPath
    }
}



function Backup-FileList($job, $sourceFiles) {
    foreach($sourceFile in $sourceFiles) {
        if(!($sourceFile -is [System.IO.DirectoryInfo])) {
            Backup-File $job $sourceFile
        }
    }
}

function Walk-SourceTree($job, $source) {
    Write-Host "$source"
    $unfilteredSourceFiles = @(Get-ChildItem $source)
    if(!$unfilteredSourceFiles) {
        $unfilteredSourceFiles = @() #http://blog.coretech.dk/jgs/powershell-how-to-create-an-empty-array/
    }
    $filteredSourceFiles = Filter-Files $unfilteredSourceFiles $job.exclude
    Backup-FileList $job $filteredSourceFiles
    
    foreach ($filteredSourceFile in $filteredSourceFiles) {
        if ($filteredSourceFile.PSIsContainer) {
            $childItems = ,(Walk-SourceTree $job $filteredSourceFile.FullName)
            $filteredSourceFiles = $unfilteredSourceFiles + $childItems
        }
    }

    return ,$filteredSourceFiles #https://stackoverflow.com/q/18476634/270155
}

function Run-BackupJob($job) {
    Write-Host ""
    Write-Host "Job: $($job.name)"
    Write-Host "Source: $($job.source)"
    Assert-Exists $job.source $true
    Write-Host "Destination: $($job.destination)"
    Write-Host "--------------------------"
    Assert-Exists $job.destination $true
    $filteredSourceFiles = Walk-SourceTree $job $job.source
    Write-Host "--------------------------"
}

function Build-Config() {
    if(-not($source)) { Throw "You must supply a value for -source" }
    if(-not($destination)) { Throw "You must supply a value for -destination" }
    $job = New-Object –TypeName PSObject
    $job | Add-Member -MemberType NoteProperty -Name Name -Value $Name
    $job | Add-Member -MemberType NoteProperty -Name Source -Value $source
    $job | Add-Member -MemberType NoteProperty -Name Destination -Value $destination
    $job | Add-Member -MemberType NoteProperty -Name Exclude -Value $exclude

    Print-Object $job
    $job
}

function Backup-Files( ) {

    $script:result = New-Object –TypeName PSObject
    $script:result | Add-Member -MemberType NoteProperty -Name Copied -Value (New-Object System.Collections.ArrayList($null))

    $job = Build-Config

    #Print-Object $script:config
    Run-BackupJob $job

    $script:result
}

Backup-Files