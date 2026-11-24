function Get-FolderSizes {
    <#
    .SYNOPSIS
        Shows the size of each folder in a folder.

    .DESCRIPTION
        Measures each folder directly under Path and shows the results as a table, largest first, with
        sizes in MB. Folders whose size the FileSystemObject can't report, such as some special
        folders, are measured by adding up the files they contain. Last, it returns the total size in
        GB, including the files directly in Path.

    .PARAMETER Path
        The folder whose subfolders to measure. Accepts pipeline input.

    .PARAMETER SizeMB
        Only list folders larger than this many MB. By default all folders are listed.

    .PARAMETER ExcludeFolder
        The name of a folder to leave out.

    .EXAMPLE
        Get-FolderSizes -Path 'C:\Users'

        Shows the size of each user's folder and the total.

    .EXAMPLE
        Get-FolderSizes -Path $HOME -SizeMB 500 -ExcludeFolder 'OneDrive'

        Lists the folders in your home folder that are larger than 500 MB, leaving out OneDrive.

    .NOTES
        Name: Get-FolderSizes
        Author: Unknown
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

    process {

        if (!(Test-Path $Path)) {
            throw "Invalid path. Wants gci's -path parameter."
            break
        }

        $objectFSO = New-Object -ComObject Scripting.FileSystemObject
        $Parents = Get-ChildItem $Path -Force | Where-Object { $_.PSisContainer -and $_.Name -ne $ExcludeFolder }
        $Folders = foreach ($folder in $parents) {
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
                name   = $getFolder.path
                sizeMB = $sizeMBs
            } #close new obj property
        } #close foreach folder

        #here's the output
        $Folders |
            Sort-Object @{E = { [decimal]$_.sizeMB } } -Descending |
            Where-Object { [decimal]$_.sizeMB -gt $SizeMB } |
            Format-Table -AutoSize
        #calculate the total including contents
        $sum = $Folders | Select-Object -ExpandProperty sizeMB | Measure-Object -Sum | Select-Object -ExpandProperty sum
        $sum += ( Get-ChildItem $Path | Measure-Object -Property length -Sum | Select-Object -ExpandProperty sum ) / 1mb
        $sumString = "{0:n2}" -f ($sum / 1kb)
        $sumString + " GB total"
    }
} #end function
