Function Use-Module {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [ValidateNotNullOrEmpty()]
            [String]$Name
        ,[Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ValueFromRemainingArguments=$true)]
            [ValidateSet('CurrentUser', 'AllUsers')]
            [String]$Scope = 'AllUsers'
        ,[Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ValueFromRemainingArguments=$true)]
            [String]$RequiredVersion
        ,[Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ValueFromRemainingArguments=$true)]
            [Switch]$AllowClobber
        ,[Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ValueFromRemainingArguments=$true)]
            [Switch]$AcceptLicense
    )
    Begin {}
    Process {
        # Is module available? remedy if not
        If (-not (Get-Module -ListAvailable | Where-Object {$_.Name -eq $Name})) {
            # Check if NuGet is installed, and install if needed
            If ( -not ( Get-PackageProvider -ListAvailable | Where-Object Name -eq "Nuget" ) ) {
                $null = Install-PackageProvider "Nuget" -Force -Scope $Scope -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
            }
            
            # Check if Module exists in online repository
            If ( (Find-Module -Name $Name -Verbose:$VerbosePreference -ErrorAction SilentlyContinue)) {
                
                # setup installation parameters and install module
                $imparam = @{ Name = $Name; Scope = $Scope; Force = $true }
                If ($AllowClobber)  { $imparam.AllowClobber = $true }
                If ($AcceptLicense) { $imparam.AcceptLicense = $true }
                If ($RequiredVersion) { $imparam.RequiredVersion = $RequiredVersion }
                Try {
                    Install-Module @imparam -Verbose:$VerbosePreference -WhatIf:$WhatIfPreference
                } Catch {
                    Write-Error "Install-Module for $Name failed."
                }
            }  
            Else {
                # If the module is not imported, not available and not in the online gallery then abort
                Write-Verbose "Module $Name not available and not in an online gallery."
                return $false
            }
        }

        # attempt importing module if needed
        If ( -not (Get-Module -Name $Name -ErrorAction SilentlyContinue)) {
            Try {
                Import-Module $Name -Verbose:$VerbosePreference
                Return $true
            } Catch {
                Write-Verbose "Module $Name encountered error while importing"
                Return $false
            }
        } Else { 
            Write-Verbose "Module $Name is already imported"
            Return $true
        }
    }
    End {}
}

Use-Module -Name NTFSSecurity
Use-Module -Name AdoSQLiteModule

$storedb = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"

$perm = Get-NTFSAccess $storedb

If ($perm[0].AccessRights -eq 'FullControl') {
    Invoke-AdoSQLiteNonQuery -Database $storedb -Query 'DELETE FROM SearchProducts'

    Disable-NTFSAccessInheritance $storedb
    Get-NTFSAccess $storedb | ForEach-Object {
        Remove-NTFSAccess -Account $_.Account -Path $storedb -AccessRights Write,Modify  
        Add-NTFSAccess -Account $_.Account -Path $storedb -AccessRights Read
    }
}

#Get-NTFSAccess $storedb | fl

