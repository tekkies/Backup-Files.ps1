param([string]$source, [string]$destination, [string]$name="(unnamed)", [String[]] $exclude, [switch] $testOnly)

Set-StrictMode -Version 4.0 #https://blogs.technet.microsoft.com/pstips/2014/06/17/powershell-scripting-best-practices/

$specFile = (Join-Path (Split-Path -parent $PSCommandPath) "test.backupspec")


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


function Copy-File($sourcePath, $destinationPath) {
    #Write-Host "    $($destinationPath)"
    if(!$testOnly.IsPresent) {
        Copy-Item $sourcePath $destinationPath
    }
    $script:result.Copied.Add($destinationPath)
}


function Get-DestinationPath($job, $sourceFile) {
    $tail = ($sourceFile.FullName.Replace($job.Source,"")).TrimStart("\")
    Join-Path $job.Destination $tail
}

function Backup-File($job, $sourceFile) {
    #Write-Host "    $($sourceFile.Name)"
    $destinationPath = Get-DestinationPath $job $sourceFile
    #Write-Host "        $($destinationPath)"
    if (Test-Path $destinationPath) {
        $existingFile = Get-Item $destinationPath
        if (IsSourceNewer $sourceFile $existingFile) {
            Rename-DestinationFile $job $existingFile  
            Copy-File $sourceFile.FullName $destinationPath          
        }
    } else {
        $destinationFolder = Split-Path -Parent $destinationPath
        New-Item $destinationFolder -type directory -Force
        Copy-File $sourceFile.FullName $destinationPath
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
    Write-Host "Folder:$source"
    $unfilteredSourceFiles = @(Get-ChildItem $source)
    if(!$unfilteredSourceFiles) {
        $unfilteredSourceFiles = @() #http://blog.coretech.dk/jgs/powershell-how-to-create-an-empty-array/
    }
    $filteredSourceFiles = Filter-Files $unfilteredSourceFiles $job.exclude
    Backup-FileList $job $filteredSourceFiles
    
    foreach ($filteredSourceFile in $filteredSourceFiles) {
        if ($filteredSourceFile.PSIsContainer) {
            $childItems = ,(Walk-SourceTree $job $filteredSourceFile.FullName)
            Write-Host '-------------------------------'
            Write-Host $unfilteredSourceFiles.ToString()
            Write-Host $childItems.ToString()
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
    Assert-Exists $job.destination $true
    $filteredSourceFiles = Walk-SourceTree $job $job.source
   
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