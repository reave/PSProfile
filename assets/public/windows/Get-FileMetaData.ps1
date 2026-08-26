
function Get-FileMetaData {
    <#
    .SYNOPSIS
    Retrieves metadata properties of a specified file.

    .DESCRIPTION
    The `Get-FileMetaData` function extracts metadata properties of a given file
    using the Windows Shell COM object. It returns a hashtable containing property
    names and their corresponding values.

    .PARAMETER Path
    Specifies the full path to the file for which metadata is to be retrieved.
    The path must point to an existing file.

    .OUTPUTS
    Hashtable
    A hashtable where the keys are the metadata property names and the values are
    the corresponding metadata values.

    .EXAMPLE
    PS C:\> Get-FileMetaData -Path "C:\Users\josep\Documents\example.txt"

    This command retrieves the metadata properties of the file `example.txt` and
    returns them as a hashtable.

    Path must be full path to a file.

    .NOTES
    - The function uses the Windows Shell COM object to access file metadata.
    - Only properties with non-empty names and values are included in the output.
    - The function iterates through the first 50 metadata properties.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    Begin {
        try {
            # Initialize the COM objects required for accessing file metadata.
            Write-Verbose "Initializing COM objects for file metadata retrieval."
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace((Split-Path $Path)) # Get the folder containing the file.
            if (-not $folder) {
                throw "Unable to access the folder: $(Split-Path $Path)" # Throw an error if the folder cannot be accessed.
            }
            Write-Verbose "Accessed folder: $(Split-Path $Path)"
            $file = $folder.ParseName((Split-Path $Path -Leaf)) # Get the file object within the folder.
            if (-not $file) {
                throw "Unable to access the file: $(Split-Path $Path -Leaf)" # Throw an error if the file cannot be accessed.
            }
            Write-Verbose "Accessed file: $(Split-Path $Path -Leaf)"
        } catch {
            # Handle errors during COM object initialization.
            Write-Error "An error occurred while initializing COM objects: $_"
            throw
        }
    }
    Process {
        $props = @{} # Initialize an empty hashtable to store metadata properties.
        try {
            Write-Verbose "Retrieving metadata properties."
            for ($i = 0; $i -lt 50; $i++) {
                # Iterate through the first 50 metadata properties.
                $name = $folder.GetDetailsOf($null, $i) # Get the property name.
                $value = $folder.GetDetailsOf($file, $i) # Get the property value for the file.
                if ($name -and $value) {
                    # Only include properties with non-empty names and values.
                    Write-Verbose "Property: $name, Value: $value"
                    $props[$name] = $value # Add the property to the hashtable.
                }
            }
        } catch {
            # Handle errors during metadata retrieval.
            Write-Error "An error occurred while retrieving file metadata: $_"
            throw
        }
    }
    End {
        try {
            # Return the collected metadata properties.
            Write-Verbose "Returning metadata properties."
            return $props
        } catch {
            # Handle errors during the return process.
            Write-Error "An error occurred while returning metadata properties: $_"
            throw
        } finally {
            # Release COM objects and perform garbage collection to free resources.
            Write-Verbose "Releasing COM objects and performing garbage collection."
            try {
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($file) | Out-Null
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($folder) | Out-Null
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
            } catch {
                # Log a warning if releasing COM objects fails.
                Write-Warning "An error occurred while releasing COM objects: $_"
            } finally {
                [GC]::Collect() # Force garbage collection to clean up resources.
            }
        }
    }
}