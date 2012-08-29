# Copyright 2012 Aaron Jensen
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Assert-AdminPrivileges
{
    <#
    .SYNOPSIS
    Throws an exception if the user doesn't have administrator privileges.

    .DESCRIPTION
    Many scripts and functions require the user to be running as an administrator.  This function checks if the user is running as an administrator or with administrator privileges and **throws an exception** if the user doesn't.  

    .LINK
    Test-AdminPrivileges

    .EXAMPLE
    Assert-AdminPrivileges

    Throws an exception if the user doesn't have administrator privileges.
    #>
    [CmdletBinding()]
    param(
    )
    
    if( -not (Test-AdminPrivileges) )
    {
        throw "You are not currently running with administrative privileges.  Please re-start PowerShell as an administrator (right-click the PowerShell application, and choose ""Run as Administrator"")."
    }
}

function Convert-SecureStringToString
{
    <#
    .SYNOPSIS
    Converts a secure string into a plain text string.

    .DESCRIPTION
    Sometimes you just need to convert a secure string into a plain text string.  This function does it for you.  Yay!  Once you do, however, the cat is out of the bag and your password will be *all over memory* and, perhaps, the file system.

    .OUTPUTS
    System.String.

    .EXAMPLE
    Convert-SecureStringToString -SecureString $mySuperSecretPasswordIAmAboutToExposeToEveryone

    Returns the plain text/decrypted value of the secure string.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [Security.SecureString]
        # The secure string to convert.
        $SecureString
    )
    
    $stringPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto($stringPtr)
}

function Grant-Permissions
{
    <#
    .SYNOPSIS
    Grants permission on a file, directory or registry key.

    .DESCRIPTION
    Granting access to a file system entry or registry key requires a lot of steps.  This method reduces it to one call.  Very helpful.

    It has the advantage that it will set permissions on a file system object or a registry.  If `Path` is absolute, the correct provider (file system or registry) is used.  If `Path` is relative, the provider of the current location will be used.

    The `Permissions` attribute can be a list of [FileSystemRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx) or [RegistryRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx).

    This command will show you the values for the `FileSystemRights`:

        [Enum]::GetValues([Security.AccessControl.FileSystemRights])

    This command will show you the values for the `RegistryRights`:

        [Enum]::GetValues([Security.AccessControl.RegistryRights])

    .LINK
    http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx

    .LINK
    http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx
    
    .LINK
    Unprotect-AclAccessRules

    .EXAMPLE
    Grant-Permissions -Identity ENTERPRISE\Engineers -Permissions FullControl -Path C:\EngineRoom

    Grants the Enterprise's engineering group full control on the engine room.  Very important if you want to get anywhere.

    .EXAMPLE
    Grant-Permissions -Identity ENTERPRISE\Interns -Permissions ReadKey,QueryValues,EnumerateSubKeys -Path rklm:\system\WarpDrive

    Grants the Enterprise's interns access to read about the warp drive.  They need to learn someday, but at least they can't change anything.
    
    .EXAMPLE
    Grant-Permissions -Identity ENTERPRISE\Engineers -Permissions FullControl -Path C:\EngineRoom -Clear
    
    Grants the Enterprise's engineering group full control on the engine room.  Any non-inherited, existing access rules are removed from `C:\EngineRoom`.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The user or group getting the permissions
        $Identity,
        
        [Parameter(Mandatory=$true)]
        [string[]]
        # The permission: e.g. FullControl, Read, etc.  For file system items, use values from [System.Security.AccessControl.FileSystemRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx).  For registry items, use values from [System.Security.AccessControl.RegistryRights](http://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx).
        $Permissions,
        
        [Parameter(Mandatory=$true)]
        [string]
        # The path on which the permissions should be granted.  Can be a file system or registry path.
        $Path,
        
        [Switch]
        # Removes all non-inherited permissions on the item.
        $Clear
    )
    
    $Path = Resolve-Path $Path
    
    $pathQualifier = Split-Path -Qualifier $Path
    if( -not $pathQualifier )
    {
        throw "Unable to get qualifier on path $Path."
    }
    $pathDrive = Get-PSDrive $pathQualifier.Trim(':')
    $pathProvider = $pathDrive.Provider
    $providerName = $pathProvider.Name
    if( $providerName -ne 'Registry' -and $providerName -ne 'FileSystem' )
    {
        throw "Unsupported path: '$Path' belongs to the '$providerName' provider."
    }

    $rights = 0
    foreach( $permission in $Permissions )
    {
        $right = ($permission -as "Security.AccessControl.$($providerName)Rights")
        if( -not $right )
        {
            throw "Invalid $($providerName)Rights: $permission.  Must be one of $([Enum]::GetNames("Security.AccessControl.$($providerName)Rights"))."
        }
        $rights = $rights -bor $right
    }
    
    Write-Host "Granting $Identity $Permissions on $Path."
    # We don't use Get-Acl because it returns the whole security descriptor, which includes owner information.
    # When passed to Set-Acl, this causes intermittent errors.  So, we just grab the ACL portion of the security descriptor.
    # See http://www.bilalaslam.com/2010/12/14/powershell-workaround-for-the-security-identifier-is-not-allowed-to-be-the-owner-of-this-object-with-set-acl/
    $currentAcl = (Get-Item $Path).GetAccessControl("Access")
    
    $inheritanceFlags = [Security.AccessControl.InheritanceFlags]::None
    if( Test-Path $Path -PathType Container )
    {
        $inheritanceFlags = ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
                             [Security.AccessControl.InheritanceFlags]::ObjectInherit)
    }
    $propagationFlags = [Security.AccessControl.PropagationFlags]::None
    $accessRule = New-Object "Security.AccessControl.$($providerName)AccessRule" $identity,$rights,$inheritanceFlags,$propagationFlags,"Allow"
    if( $Clear )
    {
        $rules = $currentAcl.Access |
                    Where-Object { -not $_.IsInherited }
        
        if( $rules )
        {
            $rules | 
                ForEach-Object { $currentAcl.RemoveAccessRule( $_ ) }
        }
    }
    $currentAcl.SetAccessRule( $accessRule )
    Set-Acl $Path $currentAcl
}

function New-Credential
{
    <#
    .SYNOPSIS
    Creates a new `PSCredential` object from a given username and password.

    .DESCRIPTION
    Many PowerShell commands require a `PSCredential` object instead of username/password.  This function will create one for you.

    .OUTPUTS
    System.Management.Automation.PSCredential.

    .EXAMPLE
    New-Credential -User ENTERPRISE\picard -Password 'earlgrey'

    Creates a new credential object for Captain Picard.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The username.
        $User, 

        [Parameter(Mandatory=$true)]
        [string]
        # The password.
        $Password
    )

    return New-Object Management.Automation.PsCredential $User,(ConvertTo-SecureString -AsPlainText -Force $Password)    
}

function Test-AdminPrivileges
{
    <#
    .SYNOPSIS
    Checks if the current user is an administrator or has administrative privileges.

    .DESCRIPTION
    Many tools, cmdlets, and APIs require administative privileges.  Use this function to check.  Returns `True` if the current user has administrative privileges, or `False` if he doesn't.  Or she.  Or it.  

    This function handles UAC and computers where UAC is disabled.

    .EXAMPLE
    Test-AdminPrivileges

    Returns `True` if the current user has administrative privileges, or `False` if the user doesn't.
    #>
    [CmdletBinding()]
    param(
    )
    
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    Write-Verbose "Checking if current user '$($identity.Name)' has administrative privileges."

    $hasElevatedPermissions = $false
    foreach ( $group in $identity.Groups )
    {
        if ( $group.IsValidTargetType([Security.Principal.SecurityIdentifier]) )
        {
            $groupSid = $group.Translate([Security.Principal.SecurityIdentifier])
            if ( $groupSid.IsWellKnown("AccountAdministratorSid") -or $groupSid.IsWellKnown("BuiltinAdministratorsSid"))
            {
                return $true
            }
        }
    }

    return $false
}

function Unprotect-AclAccessRules
{
    <#
    .SYNOPSIS
    Removes access rule protection on a file or registry path.
    
    .DESCRIPTION
    New items in the registry or file system will usually inherit ACLs from its parent.  This function stops an item from inheriting rules from its, and will optionally preserve the existing inherited rules.  Any existing, non-inherited access rules are left in place.
    
    .LINK
    Grant-Permissions
    
    .EXAMPLE
    Unprotect-AclAccessRules -Path C:\Projects\Carbon
    
    Removes all inherited access rules from the `C:\Projects\Carbon` directory.  Non-inherited rules are preserved.
    
    .EXAMPLE
    Unprotect-AclAccessRules -Path hklm:\Software\Carbon -Preserve
    
    Stops `HKLM:\Software\Carbon` from inheriting acces rules from its parent, but preserves the existing, inheritied access rules.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]
        # The file system or registry path whose 
        $Path,
        
        [Switch]
        # Keep the inherited access rules on this item.
        $Preserve
    )
    
    $acl = Get-Acl -Path $Path
    $acl.SetAccessRuleProtection( $true, $Preserve )
    $acl | Set-Acl -Path $Path
}

