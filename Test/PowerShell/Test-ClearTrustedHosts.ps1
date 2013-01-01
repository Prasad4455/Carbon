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

& (Join-Path $TestDir ..\..\Carbon\Import-Carbon.ps1 -Resolve)

# Only administratos can update trusted hosts.
if( Test-AdminPrivileges )
{
    $originalTrustedHosts = $null

    function Setup
    {
        $originalTrustedHosts = @( Get-TrustedHosts )
    }

    function TearDown
    {
        if( $originalTrustedHosts )
        {
            Set-TrustedHosts -Entries $originalTrustedHosts
        }
    }

    function Test-ShouldRemoveTrustedHosts
    {
        Set-TrustedHosts 'example.com'
        Assert-Equal 'example.com' (Get-TrustedHosts)
        Clear-TrustedHosts
        Assert-Empty (Get-TrustedHosts)
    }
    
    function Test-ShouldSupportWhatIf
    {
        Set-TrustedHosts 'example.com'
        Assert-Equal 'example.com' (Get-TrustedHosts)
        Clear-TrustedHosts -WhatIf
        Assert-Equal 'example.com' (Get-TrustedHosts)
    }
    
        
}
else
{
    Write-Warning "Only Administrators can modify the trusted hosts list."
}