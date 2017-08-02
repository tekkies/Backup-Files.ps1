```
NAME
    Backup-Files.ps1
    
SYNOPSIS
    Backup files, preserving old file versions.
    
    
SYNTAX
    C:\Users\ajoiner\Google Drive\dev\src\Backup-Files.ps1\Backup-Files.ps1 [[-Source] <String>] [[-Destination] <String>] [[-Name] <String>] 
    [[-Exclude] <String[]>] [-WhatIf] [-Help] [<CommonParameters>]
    
    
DESCRIPTION
    Intended for backing up files to a set of external drives, keeping old versions of files and allowing the backups to be trimmed easily.  
    Timestamps are used to determine if a new copy of a file should be made.  If a new copy is made, the original is renamed to include a UTC 
    timestamp in the name.
    

PARAMETERS
    -Source <String>
        The directory you want to backup.
        
    -Destination <String>
        The backup directory - this directory must already exist!
        
    -Name <String>
        The name of this backup set.
        
    -Exclude <String[]>
        Exclude patterns in REGEX form.
        
    -WhatIf [<SwitchParameter>]
        Don't do the actual backup - just report what would be backed up.
        
    -Help [<SwitchParameter>]
        Show this help.
        
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see 
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216). 
    
    -------------------------- EXAMPLE 1 --------------------------
    
    PS C:\>Backup-Files.ps1 -source "C:\Dev\src" -destination "V:\src" -Name "Source Code" -exclude "\.exe$", "\\bin\\debug\\" -WhatIf
    
```
