##
## Copyright (c) Microsoft Corporation.
## Licensed under the MIT license.
##
## Written by the SQL Server Network Support Team
## GitHub Site: https://github.com/microsoft/CSS_SQL_Networking_Tools/wiki
##

## Set-ExecutionPolicy Unrestricted -Scope CurrentUser

#=======================================Script parameters =====================================

# Several mutually exclusive parameter sets are defined
#
# .\SQLTrace.ps1 -Help
# .\SQLTrace.ps1 -Setup [-INIFile SQLTrace.ini]
# .\SQLTrace.ps1 -Start [-StopAfter 0] [-INIFile SQLTrace.ini]
# .\SQLTrace.ps1 -Stop [-INIFile SQLTrace.ini]
# .\SQLTrace.ps1 -Cleanup [-INIFile SQLTrace.ini]
#

param
(
    [Parameter(ParameterSetName = 'Help', Mandatory=$true)]
    [switch] $Help,
     
    [Parameter(ParameterSetName = 'Setup', Mandatory=$true)]
    [switch] $Setup,

    [Parameter(ParameterSetName = 'Start', Mandatory=$true)]
    [switch] $Start,

    [Parameter(ParameterSetName = 'Start', Mandatory=$false)]
    [int] $StopAfter = [int]::Parse("0"),

    [Parameter(ParameterSetName = 'Stop', Mandatory=$false)]
    [switch] $Stop,

    [Parameter(ParameterSetName = 'Cleanup', Mandatory=$true)]
    [switch] $Cleanup,

    [Parameter(ParameterSetName = 'Setup', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Start', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Stop', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Cleanup', Mandatory=$false)]
    [string] $INIFile = "SQLTrace.ini"

)


#=======================================Globals =====================================

# [console]::TreatControlCAsInput = $false   # may change this later
[string]$global:CurrentFolder = ""
[string]$global:LogFolderName = ""
[string]$global:LogFolderEnvName = "SQLTraceFolderName"

$global:INISettings = $null                  # set in ReadINIFile
$global:RunningSettings = $null

Function Main
{    
    ReadINIFile
    DisplayINIValues  # TODO hide

    if     ($Setup)    { DisplayLicenseAndHeader }
    elseif ($Start)    { StartTraces }
    elseif ($Stop)     { StopTraces }
    elseif ($Cleanup)  { }
    else               { DisplayLicenseAndHeader; DisplayHelpMessage }
}

Function DisplayLicenseAndHeader
{
# Text is left-justified to prevent leading spaces. Column width not to exceed 79 for smaller console sizes.
"
  _________________   .____   ___________                                
 /   _____/\_____  \  |    |  \__    ___/_______ _____     ____   ____
 \_____  \  /  / \  \ |    |    |    |   \_  __ \\__  \  _/ ___\_/ __ \
 /        \/   \_/.  \|    |___ |    |    |  | \/ / __ \_\  \___\  ___/
/_______  /\_____\ \_/|_______ \|____|    |__|   (____  / \___  >\___  >
        \/        \__>        \/                      \/      \/     \/

                     SQLTrace.ps1 version 0.1 Alpha
               by the Microsoft SQL Server Networking Team

MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the 'Software'), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE

Disclaimers

This tool does not communicate with any external systems or with Microsoft.
This tool does not make a connection to SQL Server, IIS, or other services.
This tool DOES take network traces and other traces on the local machine and
records them to the local folder. This is controlled by the SQLTrace.ini file.
"
}

Function DisplayHelpMessage
{
"
Usage:

   .\SQLTrace.ps1 -Help
   .\SQLTrace.ps1 -Setup [-INIFile SQLTrace.ini]
   .\SQLTrace.ps1 -Start [-StopAfter 0] [-INIFile SQLTrace.ini]
   .\SQLTrace.ps1 -Stop [-INIFile SQLTrace.ini]
   .\SQLTrace.ps1 -Cleanup [-INIFile SQLTrace.ini]
"
}

Function ReadINIFile
{
    $global:INISettings = New-Object IniValueClass
    $fileName = $INIFile

    $fileData = get-content $fileName

    foreach ($line in $fileData)
    {
        # trim leading and trailing spaces and comments
        [String]$l = $line
        $l = $l.Trim()
        $hashPos = $l.IndexOf('#')
        if ($hashPos -ge 0) { $l = $l.SubString(0, $hashPos) }
        if ($l.Trim() -eq "") { continue }

        # $l contains some text, split it on the = character and trim the parts

        [String[]]$lineParts = $l.Split('=')

        if ($lineParts.Length -ne 2)
        {
            "Badly formatted setting: $l"
            continue
        }

        $keyWord = $lineParts[0].Trim()
        $value = $lineParts[1].Trim()

        
        switch($keyWord)
        {
           "BIDTrace"          { $global:INISettings.BIDTrace           = $value }
           "BIDWow"            { $global:INISettings.BIDWow             = $value }
           "BIDProviderList"   { $global:INISettings.BIDProviderList    = $value ; while ( $global:INISettings.BIDProviderList.IndexOf("  ") -ge 0) { $global:INISettings.BIDProviderList = $global:INISettings.BIDProviderList.Replace("  ", " ") } } # remove extra spaces between provider names
           "NETTrace"          { $global:INISettings.NetTrace           = $value }
           "NETSH"             { $global:INISettings.NETSH              = $value }
           "NETMON"            { $global:INISettings.NETMON             = $value }
           "WireShark"         { $global:INISettings.WireShark          = $value }
           "PktMon"            { $global:INISettings.PktMon             = $value }
           "AuthTrace"         { $global:INISettings.AuthTrace          = $value }
           "SSL"               { $global:INISettings.SSL                = $value }
           "CredSSP_NTLM"      { $global:INISettings.CredSSP            = $value }
           "Kerberos"          { $global:INISettings.Kerberos           = $value }
           "LSA"               { $global:INISettings.LSA                = $value }
           "EventViewer"       { $global:INISettings.EventViewer        = $value }
           default             { "Unknown keyword $keyWord in line: $l" }
        }
    }
}

Function DisplayINIValues
{
    "Read the ini file: $fileName"
    ""
    "BIDTrace            " + $global:INISettings.BIDTrace
    "BIDWow              " + $global:INISettings.BIDWow
    "BIDProviderList     " + $global:INISettings.BIDProviderList
    ""
    "NETTrace            " + $global:INISettings.NETTrace
    "NETSH               " + $global:INISettings.NETSH
    "NETMON              " + $global:INISettings.NETMON
    "WireShark           " + $global:INISettings.WireShark
    "PktMon              " + $global:INISettings.PktMon
    ""
    "AuthTrace           " + $global:INISettings.AuthTrace
    "SSL                 " + $global:INISettings.SSL
    "CredSSP_NTLM        " + $global:INISettings.CredSSP
    "Kerberos            " + $global:INISettings.Kerberos
    "LSA                 " + $global:INISettings.LSA
    "EventViewer         " + $global:INISettings.EventViewer
}

# ================================= Class Definitions ===========================

class INIValueClass             # contains all the INI file settings in one place
{
    [string] $BidTrace = "No"            # No | Yes
    [string] $BidWow = "No"              # No | Yes | Both
    [string] $BidProviderList = ""

    [string] $NetTrace = "No"
    [string] $Netsh = "No"
    [string] $Netmon = "No"
    [string] $Wireshark = "No"
    [string] $Pktmon = "No"

    [string] $AuthTrace = "No"
    [string] $SSL = "No"
    [string] $Kerberos = "No"
    [string] $LSA = "No"
    [string] $Credssp = "No"
    [string] $EventViewer = "No"
}

class RunningSettings
{
    [System.Diagnostics.Process] $WiresharkProcess = $null
    [System.Diagnostics.Process] $NetmonProcess = $null
}

Function StartTraces
{

    $PSDefaultParameterValues['*:Encoding'] = 'Ascii'
    $global:RunningSettings = New-Object RunningSettings
    StartBIDTraces
    StartNetworkTraces
    StartAuthenticationTraces

}

Function GETBIDTraceGuid($bidProvider)
{
    
    switch($bidProvider)
    {
       "MSDADIAG"                         { return "{8B98D3F2-3CC6-0B9C-6651-9649CCE5C752} 0x630ff  0   MSDADIAG.ETW "}
       "ADODB"                            { return "{04C8A86F-3369-12F8-4769-24E484A9E725} 0x630ff  0   ADODB.1 "}
       "ADOMD"                            { return "{7EA56435-3F2F-3F63-A829-F0B35B5CAD41} 0x630ff  0   ADOMD.1 "}
       "BCP"                              { return "{24722B88-DF97-4FF6-E395-DB533AC42A1E} 0x630ff  0   BCP.1 "}
       "BCP10"                            { return "{ED303448-5479-CA3F-5686-E020BA4F47F9} 0x630ff  0   BCP10.1 "}
       "DBNETLIB"                         { return "{BD568F20-FCCD-B948-054E-DB3421115D61} 0x630ff  0   DBNETLIB.1 "}
       "MSADCE"                           { return "{76DBA919-5A36-FC80-2CAD-3185532B7CB1} 0x630ff  0   MSADCE.1 "}
       "MSADCF"                           { return "{101C0E21-EBBA-A60A-EC3D-58797788928A} 0x630ff  0   MSADCF.1 "}
       "MSADCO"                           { return "{5C6CE734-1B3E-705E-C2AB-B272D99AAF8F} 0x630ff  0   MSADCO.1 "}
       "MSADDS"                           { return "{13CD7F92-5BAA-8C7C-3D72-B69FAC139A46} 0x630ff  0   MSADDS.1 "}
       "MSADOX"                           { return "{6C770D53-0441-AFD4-DCAB-1D89155FECFC} 0x630ff  0   MSADOX.1 "}
       "MSDAORA"                          { return "{F02A5DAC-6DB2-F77F-F6A8-6404FE697B7D} 0x630ff  0   MSDAORA.1 "}
       "MSDAPRST"                         { return "{64A552E0-6C60-B907-E59C-10F1DFF76B0D} 0x630ff  0   MSDAPRST.1 "}
       "MSDAREM"                          { return "{564F1E24-FC86-28E1-74F8-5CA0D950BEE0} 0x630ff  0   MSDAREM.1 "}
       "MSDART"                           { return "{CEB7253C-BB96-9DFE-51D1-53D966D0CF8B} 0x630ff  0   MSDART.1 "}
       "MSDASQL"                          { return "{B6501BA0-C61A-C4E6-6FA2-A4E7F8C8E7A0} 0x630ff  0   MSDASQL.1 "}
       "MSDATL3"                          { return "{87B93A44-1F73-EC83-7261-2DFC972D9B1E} 0x630ff  0   MSDATL3.1 "}
       "ODBC"                             { return "{F34765F6-A1BE-4B9D-1400-B8A12921F704} 0x630ff  0   ODBC.1 "}
       "ODBCBCP"                          { return "{932B59F1-90C2-D8BA-0956-3975C344AE2B} 0x630ff  0   ODBCBCP.1 "}
       "OLEDB"                            { return "{0DD082C4-66F2-271F-74BA-2BF1F9F65C66} 0x630ff  0   OLEDB.1 "}
       "RowsetHelper"                     { return "{74A75B02-36D8-EDE6-D10E-95B691503408} 0x630ff  0   RowsetHelper.1 "}
       "SQLBROWSER"                       { return "{FC9F92E6-D521-9C9A-1D8C-D8980B9978A9} 0x630ff  0   SQLBROWSER.1 "}
       "SQLOLEDB"                         { return "{C5BFFE2E-9D87-D568-A09E-08FC83D0C7C2} 0x630ff  0   SQLOLEDB.1 "}
       "SQLNCLI"                          { return "{BA798F36-2325-EC5B-ECF8-76958A2AF9B5} 0x630ff  0   SQLNCLI.1 "}
       "SQLNCLI10"                        { return "{A9377239-477A-DD22-6E21-75912A95FD08} 0x630ff  0   SQLNCLI10.1 "}
       "SQLNCLI11"                        { return "{2DA81B52-908E-7DB6-EF81-76856BB47C4F} 0x630ff  0   SQLNCLI11.1 "}
       "SQLSERVER.SNI"                    { return "{AB6D5EEB-0132-74AB-C5F5-B23E1644DADA} 0x630ff  0   SQLSERVER.SNI.1 "}
       "SQLSERVER.SNI10"                  { return "{48D59D84-105B-00FA-6B49-03462F696737} 0x630ff  0   SQLSERVER.SNI10.1 "}
       "SQLSERVER.SNI11"                  { return "{B2A28C42-A7C2-1563-97CC-3BE49FDA19F9} 0x630ff  0   SQLSERVER.SNI11.1 "}
       "SQLSERVER.SNI12"                  { return "{5BD84A98-C66F-1694-6E42-B18A6243602B} 0x630ff  0   SQLSERVER.SNI12.1 "}
       "SQLSRV32"                         { return "{4B647745-F438-0A42-F870-5DBD29949C99} 0x630ff  0   SQLSRV32.1 "}
       "MSODBCSQL11"                      { return "{7C360F7F-7102-250A-A233-F9BEBB9875C2} 0x630ff  0   MSODBCSQL11.1 "}
       "MSODBCSQL13"                      { return "{85DC6E48-9394-F805-45C9-C8B2ACA2E7FE} 0x630ff  0   MSODBCSQL13.1 "}
       "MSODBCSQL17"                      { return "{053A11C4-BC2B-F7CE-4A10-9D2602643DA0} 0x630ff  0   MSODBCSQL17.1 "}
       "System.Data"                      { return "{914ABDE2-171E-C600-3348-C514171DE148} 0x630ff  0   System.Data.1 "}
       "System.Data.OracleClient"         { return "{DCD90923-4953-20C2-8708-01976FB15287} 0x630ff  0   System.Data.OracleClient.1 "}
       "System.Data.SNI"                  { return "{C9996FA5-C06F-F20C-8A20-69B3BA392315} 0x630ff  0   System.Data.SNI.1 "}
       "System.Data.Entity"               { return "{A68D8BB7-4F92-9A7A-D50B-CEC0F44C4808} 0x630ff  0   System.Data.Entity.1 "}
       "SQLJDBC,XA"                       { return "{172E580D-9BEF-D154-EABB-83429A6F3718} 0x630ff  0   SQLJDBC,XA.1 "}
       "MSOLEDBSQL"                       { return "{EE7FB59C-D3E8-9684-AEAC-B214EFD91B31} 0x630ff  0   MSOLEDBSQL.1 "}
       "MSOLEDBSQL19"                     { return "{699773CA-18E7-57DF-5718-C244760A9F44} 0x630ff  0   MSOLEDBSQL19.1 "}

    }


}


Function StartBIDTraces
{
    $vGUIDs = [System.Collections.ArrayList]::new()
    if($global:INISettings.BidTrace -eq "Yes")
    {
        if($global:INISettings.BidWow -eq "Only")
        {
            "BIDTrace - Set BIDInterface WOW64 MSDADIAG.DLL"
            reg add HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
        }
        elseif($global:INISettings.BidWow -eq "Both")
        {
            "BIDTrace - Set BIDInterface MSDADIAG.DLL"
            reg  add HKLM\Software\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
            "BIDTrace - Set BIDInterface WOW64 MSDADIAG.DLL"
            reg add HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
        }
        else ## BIDWOW = No
        {
        "BIDTrace - Set BIDInterface MSDADIAG.DLL"
        reg  add HKLM\Software\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
        }

        ## Get Provider GUIDs - Add MSDIAG by default
        $guid = GETBIDTraceGUID("MSDADIAG")
        $vGUIDs.Add($guid) | out-null

        ## Add the ones listed in the INI file
        $global:INISettings.BidProviderList.Split(" ") | ForEach {
        $guid = GETBIDTraceGUID($_)
        $vGUIDs.Add($guid) | out-null
        }

        if((Test-Path ".\BIDTraces" -PathType Container) -eq $false){
        md "BIDTraces" > $null
        }
        
        $cRow=0
        foreach($guid in $vGUIDs)
        { 
          if($cRow -gt 0) 
          {
            $guid | Out-File -FilePath ".\BIDTraces\ctrl.guid" -Append
          }
          else
          {
            $guid | Out-File -FilePath ".\BIDTraces\ctrl.guid"
          }
          $cRow++

        }

        #$vGUIDs > ".\BIDTraces\ctrl.guid"
        logman start msbidtraces -pf ".\BIDTraces\ctrl.guid" -o ".\BIDTraces\BIDTrace.etl" -bs 1024 -nb 1024 1024 -mode Preallocate+Circular -max 1000 -ets

    }

}

Function StartWireshark
{
    ## Get Number of Devices
    $WiresharkPath = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Wireshark.exe\' -Name Path
    $WiresharkCmd = $WiresharkPath + "\dumpcap.exe"
    $DeviceList = invoke-expression '& $WiresharkCmd -D'
    $ArgumentList = ""
    For($cDevices=0;$cDevices -lt $DeviceList.Count;$cDevices++) { $ArgumentList = $ArgumentList + " -i " + ($cDevices+1) }
    ##Prepare command arguments 
    $ArgumentList = $ArgumentList + " -w .\NetworkTraces\NetworkTraces.pcap -b filesize:200000 -b files:10"
    $WiresharkProcess = Start-Process $WiresharkCmd -PassThru -NoNewWindow -ArgumentList $ArgumentList
        "Wireshark is running with PID: " + $global:RunningSettings.WiresharkProcess.ID

}


Function StartNetworkMonitor
{

    #Look for the path where Wireshark is installed
    $NMCap = Get-ItemPropertyValue -Path 'HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Netmon3\' -Name InstallDir

    $NMCap = '"' + $NMCap + "nmcap.exe" + '" '
    $ArgumentList = "/network * /capture /file .\NetworkTraces\NetworkTraces.chn:2048M /StopWhen /Frame dns.qrecord.questionname.Contains('stopmstrace')"
    
    #Start the capture
    $global:RunningSettings.NetmonProcess = Start-Process $NMCap -PassThru -NoNewWindow -ArgumentList $ArgumentList
    "Network Monitor is running with PID: " + $global:RunningSettings.NetmonProcess.ID
    
}
Function StartNetworkTraces
{
    
    if($global:INISettings.NETTrace -eq "Yes")
    {

        "Starting Network Traces..."
        if((Test-Path ".\NetworkTraces" -PathType Container) -eq $false){
        md "NetworkTraces" > $null
        }

        if($global:INISettings.NETSH -eq "Yes")
        {
            "Starting NETSH..."
            $commandLine = "netsh trace start capture=yes overwrite=yes tracefile=.\NetworkTraces\" + $env:computername +".etl filemode=circular maxSize=200MB"
            Invoke-Expression $commandLine
        }
        if($global:INISettings.NETMON -eq "Yes")
        {
            "Starting Network Monitor..."
            StartNetworkMonitor
        }
        if($global:INISettings.WIRESHARK -eq "Yes")
        {
            "Starting Wireshark..."
            StartWireshark
        }
        

    }
}

Function StartAuthenticationTraces
{
    if($global:INISettings.AuthTrace -eq "Yes")
    {
 
        if((Test-Path ".\Auth" -PathType Container) -eq $false){
           md "Auth" > $null
        }
   
        if($global:INISettings.Kerberos -eq "Yes")
        {
            Write-Host "Starting Kerberos ETL Traces..."

            # **Kerberos**
            $Kerberos = @(
            '{6B510852-3583-4e2d-AFFE-A67F9F223438}!0x7ffffff'
            '{60A7AB7A-BC57-43E9-B78A-A1D516577AE3}!0xffffff'
            '{FACB33C4-4513-4C38-AD1E-57C1F6828FC0}!0xffffffff'
            '{97A38277-13C0-4394-A0B2-2A70B465D64F}!0xff'
            '{8a4fc74e-b158-4fc1-a266-f7670c6aa75d}!0xffffffffffffffff'
            '{98E6CFCB-EE0A-41E0-A57B-622D4E1B30B1}!0xffffffffffffffff'
            ) 

            ##Purging Tickets
            klist purge | Out-Null
            klist purge -li 0x3e7 | Out-Null
            klist purge -li 0x3e4 | Out-Null
            klist purge -li 0x3e5 | Out-Null
    
            # Kerberos Logging to SYSTEM event log in case this is a client
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters /v LogLevel /t REG_DWORD /d 1 /f
    
            logman start "Kerberos" -o .\Auth\Kerberos.etl -ets

            ForEach($KerberosProvider in $Kerberos)
            {
                # Update Logman Kerberos
                $KerberosParams = $KerberosProvider.Split('!')
                $KerberosSingleTraceGUID = $KerberosParams[0]
                $KerberosSingleTraceFlags = $KerberosParams[1]    
                logman update trace "Kerberos" -p `"$KerberosSingleTraceGUID`" $KerberosSingleTraceFlags 0xff -ets | Out-Null
            }
        }
        
        if($global:INISettings.Credssp -eq "Yes")
        {

            Write-Host "Starting CredSSP/NTLM Traces..."
            # **Ntlm_CredSSP**
            $Ntlm_CredSSP = @(
            '{5BBB6C18-AA45-49b1-A15F-085F7ED0AA90}!0x5ffDf'
            '{AC69AE5B-5B21-405F-8266-4424944A43E9}!0xffffffff'
            '{6165F3E2-AE38-45D4-9B23-6B4818758BD9}!0xffffffff'
            '{AC43300D-5FCC-4800-8E99-1BD3F85F0320}!0xffffffffffffffff'
            '{DAA6CAF5-6678-43f8-A6FE-B40EE096E06E}!0xffffffffffffffff'
            )

            logman create trace "Ntlm_CredSSP" -o .\Auth\Ntlm_CredSSP.etl -ets

            ForEach($Ntlm_CredSSPProvider in $Ntlm_CredSSP)
            {
                # Update Logman Ntlm_CredSSP
                $Ntlm_CredSSPParams = $Ntlm_CredSSPProvider.Split('!')
                $Ntlm_CredSSPSingleTraceGUID = $Ntlm_CredSSPParams[0]
                $Ntlm_CredSSPSingleTraceFlags = $Ntlm_CredSSPParams[1]
        
                logman update trace "Ntlm_CredSSP" -p `"$Ntlm_CredSSPSingleTraceGUID`" $Ntlm_CredSSPSingleTraceFlags 0xff -ets | Out-Null
            }
        }
        

        if($global:INISettings.SSL -eq "Yes")
        {
            Write-Host "Starting SSL Traces..."
            # **SSL**
            $SSL = @(
            '{37D2C3CD-C5D4-4587-8531-4696C44244C8}!0x4000ffff'
            )

            # Start Logman SSL     
            logman start "SSL" -o .\Auth\SSL.etl -ets

            ForEach($SSLProvider in $SSL)
            {
                # Update Logman SSL
                $SSLParams = $SSLProvider.Split('!')
                $SSLSingleTraceGUID = $SSLParams[0]
                $SSLSingleTraceFlags = $SSLParams[1]
        
                logman update trace "SSL" -p `"$SSLSingleTraceGUID`" $SSLSingleTraceFlags 0xff -ets | Out-Null
            }

        }

        
        if($global:INISettings.LSA -eq "Yes")
        {
          
            Write-Host "Starting LSA Traces..."

            # **Netlogon logging**
            nltest /dbflag:0x2EFFFFFF 2>&1 | Out-Null

            # **LSA**
            $LSA = @(
            '{D0B639E0-E650-4D1D-8F39-1580ADE72784}!0xC43EFF'
            '{169EC169-5B77-4A3E-9DB6-441799D5CACB}!0xffffff'
            '{DAA76F6A-2D11-4399-A646-1D62B7380F15}!0xffffff'
            '{366B218A-A5AA-4096-8131-0BDAFCC90E93}!0xfffffff'
            '{4D9DFB91-4337-465A-A8B5-05A27D930D48}!0xff'
            '{7FDD167C-79E5-4403-8C84-B7C0BB9923A1}!0xFFF'
            '{CA030134-54CD-4130-9177-DAE76A3C5791}!0xfffffff'
            '{5a5e5c0d-0be0-4f99-b57e-9b368dd2c76e}!0xffffffffffffffff'
            '{2D45EC97-EF01-4D4F-B9ED-EE3F4D3C11F3}!0xffffffffffffffff'
            '{C00D6865-9D89-47F1-8ACB-7777D43AC2B9}!0xffffffffffffffff'
            '{7C9FCA9A-EBF7-43FA-A10A-9E2BD242EDE6}!0xffffffffffffffff'
            '{794FE30E-A052-4B53-8E29-C49EF3FC8CBE}!0xffffffffffffffff'
            '{ba634d53-0db8-55c4-d406-5c57a9dd0264}!0xffffffffffffffff'
            )
    
            #Registry LSA
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v SPMInfoLevel /t REG_DWORD /d 0xC43EFF /f 2>&1
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LogToFile /t REG_DWORD /d 1 /f 2>&1
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v NegEventMask /t REG_DWORD /d 0xF /f 2>&1


            # Start Logman LSA
            $LSASingleTraceName = "LSA"
            logman create trace $LSASingleTraceName -o .\Auth\LSA.etl -ets

            ForEach($LSAProvider in $LSA)
                {
                    # Update Logman LSA
                    $LSAParams = $LSAProvider.Split('!')
                    $LSASingleTraceGUID = $LSAParams[0]
                    $LSASingleTraceFlags = $LSAParams[1]
        
                    logman update trace $LSASingleTraceName -p `"$LSASingleTraceGUID`" $LSASingleTraceFlags 0xff -ets | Out-Null
                }

           Copy-Item -Path "$($env:windir)\debug\Netlogon.*" -Destination .\Auth -Force 2>&1 
           Copy-Item -Path "$($env:windir)\system32\Lsass.log" -Destination .\Auth -Force 2>&1 

        }

        if($global:INISettings.EventViewer -eq "Yes")
        {

            Write-Host "Enabling/Collecting Event Viewer Logs..."
            # Enable Eventvwr logging
            wevtutil.exe set-log "Microsoft-Windows-CAPI2/Operational" /enabled:true /rt:false /q:true 2>&1 
            wevtutil.exe export-log "Microsoft-Windows-CAPI2/Operational" .\Auth\Capi2_Oper.evtx /overwrite:true 2>&1 
            # wevtutil.exe clear-log "Microsoft-Windows-CAPI2/Operational" 2>&1 | Out-Null
            wevtutil.exe sl "Microsoft-Windows-CAPI2/Operational" /ms:102400000 2>&1
            wevtutil.exe set-log "Microsoft-Windows-Kerberos/Operational" /enabled:true /rt:false /q:true 2>&1
            # wevtutil.exe clear-log "Microsoft-Windows-Kerberos/Operational" 2>&1 | Out-Null

        }
    }
}


Function StopTraces
{
    $global:RunningSettings = New-Object RunningSettings
    StopBIDTraces
    StopNetworkTraces
    StopAuthenticationTraces
}

Function StopBIDTraces
{


    if($global:INISettings.BidTrace -eq "Yes")
    {
        if($global:INISettings.BidWow -eq "Only")
        {
            "BIDTrace - Unset BIDInterface WOW64 MSDADIAG.DLL"
            reg delete HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /f
        }
        elseif($global:INISettings.BidWow -eq "Both")
        {
            "BIDTrace - Unset BIDInterface MSDADIAG.DLL"
            reg delete HKLM\Software\Microsoft\BidInterface\Loader /v :Path /f

            "BIDTrace - Unset BIDInterface WOW64 MSDADIAG.DLL"
            reg delete HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /f
        }
        else ## BIDWOW = No
        {
        "BIDTrace - Unset BIDInterface MSDADIAG.DLL"
        reg delete HKLM\Software\Microsoft\BidInterface\Loader /v :Path /f
        }

        logman stop msbidtraces -ets

    }

}


Function StopNetworkTraces
{
    
    if($global:INISettings.NETTrace -eq "Yes")
    {

        "Stopping Network Traces..."
        if($global:INISettings.NETSH -eq "Yes")
        {
            "Stopping NETSH..."
            netsh trace stop
        }
        if($global:INISettings.NETMON -eq "Yes")
        {
            $NetmonPID = Get-Process -Name "nmcap"
            "Stopping Network Monitor with PID: " + $NetmonPID.ID
            nslookup "stopmstrace.microsoft.com" 2>&1 | Out-Null
        }
        if($global:INISettings.WIRESHARK -eq "Yes")
        {
            $WiresharkPID = Get-Process -Name "dumpcap"
            "Stopping Wireshark with PID: " + $WiresharkPID.ID
            Stop-Process -Name "dumpcap" -Force
        }


    }
}

Function StopAuthenticationTraces
{

    if($global:INISettings.AuthTrace -eq "Yes")
    {

        if($global:INISettings.Kerberos -eq "Yes")
        {
            Write-Host "Stopping Kerberos ETL Traces..."
            logman stop "Kerberos" -ets
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters /v LogLevel /f  2>&1
        }
        if($global:INISettings.Credssp -eq "Yes")
        {
            Write-Host "Stopping CredSSP/NTLM Traces..."
            logman stop "Ntlm_CredSSP" -ets
        }
        if($global:INISettings.SSL -eq "Yes")
        {
            Write-Host "Stopping SSL Traces..."
            logman stop "SSL" -ets
        }
        if($global:INISettings.LSA -eq "Yes")
        {
            Write-Host "Stopping LSA Traces..."
            #Netlogon
            nltest /dbflag:0x0  2>&1 | Out-Null
            #LSA
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v SPMInfoLevel /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LogToFile /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v NegEventMask /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\NegoExtender\Parameters /v InfoLevel /f  2>&1 
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Pku2u\Parameters /v InfoLevel /f  2>&1
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgInfoLevel /f  2>&1
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgTraceOptions /f  2>&1

            logman stop "LSA" -ets

            Copy-Item -Path "$($env:windir)\debug\Netlogon.*" -Destination .\Auth -Force 2>&1
            Copy-Item -Path "$($env:windir)\system32\Lsass.log" -Destination .\Auth -Force 2>&1

        }

    
        if($global:INISettings.EventViewer -eq "Yes")
        {

            Write-Host "Disabling/Collecting Event Viewer Logs..."
            # *** Event/Operational logs
            wevtutil.exe set-log "Microsoft-Windows-CAPI2/Operational" /enabled:false  2>&1
            wevtutil.exe export-log "Microsoft-Windows-CAPI2/Operational" .\Auth\Capi2_Oper.evtx /overwrite:true  2>&1
            wevtutil.exe set-log "Microsoft-Windows-Kerberos/Operational" /enabled:false  2>&1
            wevtutil.exe export-log "Microsoft-Windows-Kerberos/Operational" .\Auth\Kerb_Oper.evtx /overwrite:true  2>&1

            #TODO: Reduce the amount of logs of EVTX + TXT 
            wevtutil.exe export-log SECURITY .\Auth\Security.evtx /overwrite:true  2>&1
            wevtutil.exe export-log SYSTEM .\Auth\System.evtx /overwrite:true  2>&1
            wevtutil.exe export-log APPLICATION .\Auth\Application.evtx /overwrite:true  2>&1


        }


    }
    
    

}

# ================================= start everything here =======================
Main
# ===============================================================================










