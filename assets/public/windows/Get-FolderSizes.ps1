function Get-FolderSizes {
    <#
.SYNOPSIS
    Get the size of folders
.DESCRIPTION
    Get the size of folders in the directory
.PARAMETER Path
    The path to get folder sizes from
.PARAMETER SizeMB
    Specify if yo uwant the size in MB
.PARAMETER ExcludeFolder
    Folders to Exclude from the Get
.NOTES
    Name: Get-FolderSizes
    Author: Unknown
.ALIASES
    gfs
#>
    [cmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        $SizeMB,
        [Parameter(Mandatory = $false)]
        [string]$ExcludeFolder
    ) #close param

    Process {

        if (!(Test-Path $Path)) {
            Throw "Invalid path. Wants gci's -path parameter."
            Break
        }

        $objectFSO = New-Object -ComObject Scripting.FileSystemObject
        $Parents = Get-ChildItem $Path -Force | Where-Object { $_.PSisContainer -and $_.Name -ne $ExcludeFolder }
        $Folders = Foreach ($folder in $parents) {
            $getFolder = $objectFSO.getFolder( $folder.fullname.tostring() )
            if (!$getFolder.Size) {
                #for "special folders" like appdata
                $lengthSum = Get-ChildItem $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | `
                    Measure-Object -Sum length -ErrorAction SilentlyContinue | Select-Object -ExpandProperty sum
                $sizeMBs = "{0:N0}" -f ($lengthSum / 1mb)
            } #close if size property is null
            else { $sizeMBs = "{0:N0}" -f ($getFolder.size / 1mb) }
            #else {$sizeMBs = [int]($getFolder.size /1mb) }
            New-Object -TypeName psobject -Property @{
                name   = $getFolder.path;
                sizeMB = $sizeMBs
            } #close new obj property
        } #close foreach folder

        #here's the output
        $Folders | Sort-Object @{E = { [decimal]$_.sizeMB } } -Descending | Where-Object { [decimal]$_.sizeMB -gt $SizeMB } | Format-Table -AutoSize
        #calculate the total including contents
        $sum = $Folders | Select-Object -ExpandProperty sizeMB | Measure-Object -Sum | Select-Object -ExpandProperty sum
        $sum += ( Get-ChildItem $Path | Measure-Object -Property length -Sum | Select-Object -ExpandProperty sum ) / 1mb
        $sumString = "{0:n2}" -f ($sum / 1kb)
        $sumString + " GB total"
    }
} #end function