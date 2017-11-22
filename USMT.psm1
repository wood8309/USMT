#REQUIRES -Version 2.0

Function Start-USMTScanState () {
    <#
    .SYNOPSIS
    Capture a user profile on a remote computer.

    .DESCRIPTION
    The Start-USMTScanState function captures a user profile on a remote computer and saves the profile backup to defined location.

    .EXAMPLE
    Start-USMTScanState -UserName pwood -ComputerName caqpwood1
    Complete user profile backup of user "pwood" on computer "caqpwood1"

    .EXAMPLE
    Start-USMTScanState -UserName pwood -ComputerName caqpwood1 -Destination \\capscor1\d$\
    Complete user profile backup of user "pwood" on computer "caqpwood1" and save the profile to "\\capscor1\d$\"

    .PARAMETER UserName
    Captures the specified Username.

    .PARAMETER ComputerName
    Captures the user profile to the specified Computer.

    .PARAMETER Destination
    Specifies the path to the location where the user profile is being saved. The default is \\capwds01\d$\ProfileBackups\. 

    .PARAMETER Credential
    Specifies a user account that has permission to connect to remote computer.

    .INPUTS
    None.

    .OUTPUTS
    System.Object
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        
        [Parameter(Mandatory=$True)]
        [string]$ComputerName,
        
        [Parameter()]
        [string]$Destination = '\\capwds01\d$\ProfileBackups\',
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    process {

        $OS = ""
        $OSVersion = ""
        $OS = Get-USMTOSBitness -Computer $ComputerName
        Write-Verbose "Determining remote computer OS archeitecture"
        If ($OS -eq "32-bit"){

            Copy-Item -Path \\capwds01\deploymentshare$\Tools\x86\USMT5 -Destination \\$ComputerName\c$\windows\system32\ -Recurse -Force

        }#If

        #Remote computer is 64-bit architecture
        elseif ($OS -eq "64-Bit"){

            Copy-Item -Path \\capwds01\deploymentshare$\Tools\x64\USMT5 -Destination \\$ComputerName\c$\windows\system32\ -Recurse -Force

        }#else

        $SB = { param($user) 
                Set-Location -Path C:\windows\system32\USMT5
                & '.\scanstate.exe' C:\Temp\$User /o /i:miguser.xml /i:migapp.xml /ui:cacu\$User /ue:*\* /localonly /c
        }#SB
        Write-Verbose "Defining Script Block."
        Write-Debug "Defined Script Block."
        If ($PSCmdlet.ShouldProcess($ComputerName)) {

            #Create PS Session to remote computer.
            #Session will be removed at the end.
            $Session = New-PSSession -Credential $Credential -ComputerName $ComputerName
            Write-Verbose "Creating New PS Session on $ComputerName."

            Invoke-Command -session $Session -ScriptBlock $SB -ArgumentList $UserName
            Write-Verbose "Sending Script Block: $SB to Session: $Session."

        }#ShouldProcess

        Write-Debug "Removing USMT folder from remote computer: $ComputerName."
        Remove-Item -Path \\$ComputerName\c$\windows\system32\USMT5 -Recurse 
        Write-Verbose "Removed USMT folder from remote computer: $ComputerName." 
        
            
        Move-Item -Path \\$ComputerName\C$\Temp\$UserName -Destination $Destination$UserName
        Write-Verbose "Moving user profile backup to CAPWDS01."
            
        
        Remove-PSSession $Session
        Write-Verbose "Removing Session: $Session."
                
        Write-Host "User: $UserName on Computer: $ComputerName has been backed up!" -ForegroundColor Green
            
    }#process
}#Function

Function Start-USMTLoadState() {
     <#
    .SYNOPSIS
    Load a user profile on to a remote computer.

    .DESCRIPTION
    The Start-USMTLoadState function loads a user profile on to a remote computer.

    .EXAMPLE
    Start-USMTLoadState -UserName pwood -ComputerName caqpwood1
    Complete user profile load of user "pwood" on to computer "caqpwood1"

    .PARAMETER UserName
    Loads the specified Username.

    .PARAMETER ComputerName
    Loads the user profile to the specified Computer.

    .PARAMETER Credential
    Specifies a user account that has permission to connect to remote computer.

     .INPUTS
    None.

    .OUTPUTS
    None.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [string]$ComputerName,
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )
    process {
        
        $SB = { param($user) 
                & \\capwds01\d$\amd64\loadstate.exe \\capwds01\d$\ProfileBackups\$User /i:\\capwds01\d$\amd64\miguser.xml /i:\\capwds01\d$\amd64\migapp.xml /ui:cacu\$User /ue:*\* 
              }#SB
        Write-Verbose "Defining Script Block."

        If ($PSCmdlet.ShouldProcess($ComputerName)) {

            #Create PS Session to remote computer.
            #Session will be removed at the end.
            $Session = New-PSSession -Credential $Credential -ComputerName $ComputerName
            Write-Verbose "Creating New PS Session on $ComputerName."

            Invoke-Command -session $Session -ScriptBlock $SB -ArgumentList $UserName
            Write-Verbose "Sending Script Block: $SB to Session: $Session."
        }#ShouldProcess
                
        Remove-PSSession $Session
        Write-Verbose "Removing Session: $Session."
                
        Write-Host "User:$UserName has been loaded on to Computer:$ComputerName!" -ForegroundColor Green

    }#process


}#Function

Function Get-USMTOSBitness() {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Computer
    )
    
    try {
        (Get-WmiObject -class:Win32_OperatingSystem -computername $Computer -ErrorAction Stop).osarchitecture
    } catch {
        throw "Error connecting to $Computer"
        break
    }
    Write-Output $OSVersion
    
}#Function


Export-ModuleMember -Function Start-USMTScanState
Export-ModuleMember -Function Start-USMTLoadState