
function Get-CCimInstance
{
    <#
    .SYNOPSIS
    Calls Get-CimInstance, with a fallback to Get-WmiObject.

    .DESCRIPTION
    The `Get-CCimInstance` function calls PowerShell's `Get-CimInstance` cmdlet. If CIM isn't available, calls `Get-WmiObject` instead.

    .EXAMPLE
    Get-CCimInstance -Class 'Win32_OperatingSystem'

    Demonstrates how to use `Get-CCimInstance`. In this example, the function will call `Get-CimInstance -ClassName 'Win32_OperatingSystem'`, except when that cmdlet doesn't exist, when it calls `Get-WmiObject -Class 'Win32_OperatingSystem'`.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]        
        [String] $Class,

        [String] $Filter,

        [String] $Query
    )
    $useCim = Test-CCimAvailable
    $optionalArgs = @{ }

    if( $Filter )
    {
        $optionalArgs['Filter'] = $Filter
    }

    if( $Query )
    {
        $optionalArgs['Query'] = $Query
    }
    
    if( $useCim )
    {
        Get-CimInstance -ClassName $Class @optionalArgs
    }
    else
    {
        Get-WmiObject -Class $Class @optionalArgs
    }
}