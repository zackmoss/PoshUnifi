
function Connect-UnifiController {

    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Connect', Mandatory)]
        [string] $ControllerUrl,

        [Parameter(ParameterSetName = 'Connect')]
        [string] $ControllerPort = '8443',

        [Parameter(ParameterSetName = 'Connect', Mandatory)]
        [pscredential] $Credential
    )

    $currentProtocol = [Net.ServicePointManager]::SecurityProtocol

    if ($currentProtocol.ToString().Split(',').Trim() -notcontains 'Tls12') {

        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    $Script:unifiController = ('{0}:{1}' -f $ControllerUrl, $ControllerPort)

    $Script:loginUri = ('{0}:{1}/api/login' -f $ControllerUrl, $ControllerPort)

    $Script:unifiCredential = $Credential

    if (-not $Global:UnifiSession) {

        Write-Verbose 'Creating new websession'

        $Global:UnifiSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    }

    $body = @{
        username = $unifiCredential.UserName
        password = $unifiCredential.GetNetworkCredential().Password
    } | ConvertTo-Json

    $requestParams = @{
        Uri         = $loginUri
        Method      = 'Post'
        Body        = $body
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Global:UnifiSession
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {

        $requestParams += @{ SkipCertificateCheck = $true }
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {

        $old = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

        try {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [System.Net.Security.RemoteCertificateValidationCallback] { $true }

            $response = Invoke-RestMethod @requestParams

            if ($response.meta.rc -eq 'ok') {

                Write-Verbose -Message ('Connection successful to controller {0}' -f $Script:unifiController)
            }
        }
        finally {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old
        }
    }
    else {

        $response = Invoke-RestMethod @requestParams

        if ($response.meta.rc -eq 'ok') {

            Write-Verbose -Message ('Connection successful to controller {0}' -f $Script:unifiController)
        }
    }
}

function Disconnect-UnifiController {

    [CmdletBinding()]
    param ()

    $currentProtocol = [Net.ServicePointManager]::SecurityProtocol

    if ($currentProtocol.ToString().Split(',').Trim() -notcontains 'Tls12') {

        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    $Script:logoutUri = ('{0}/api/logout' -f $Script:unifiController)

    $requestParams = @{
        Uri         = $logoutUri
        Method      = 'Post'
        ContentType = 'application/json; charset=utf-8'
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {

        $requestParams += @{ SkipCertificateCheck = $true }
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {

        $old = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

        try {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [System.Net.Security.RemoteCertificateValidationCallback] { $true }

            $response = Invoke-RestMethod @requestParams

            if ($response.meta.rc -eq 'ok') {

                Write-Verbose -Message ('Successfully disconnected from controller {0}' -f $Script:unifiController)
            }
        }
        finally {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old
        }
    }
    else {

        $response = Invoke-RestMethod @requestParams

        if ($response.meta.rc -eq 'ok') {

            Write-Verbose -Message ('Successfully disconnected from controller {0}' -f $Script:unifiController)
        }
    }

    Remove-Variable -Name UnifiSession -Force
}

function ConvertTo-UnifiObject {

    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string] $Delimiter
    )

    $outputObject = New-Object -TypeName psobject

    foreach ($item in $InputObject) {

        $tempObject = New-Object -TypeName psobject

        if (($item | Get-Member -MemberType NoteProperty).Count -gt 2) {

            foreach ($subItem in $item) {

                $props = $subItem | Get-Member -MemberType NoteProperty

                foreach ($prop in $props) {

                    $tempObject | Add-Member -MemberType NoteProperty -Name $prop.name -Value $subItem.($prop.name)
                }
            }

            $outputObject | Add-Member -MemberType NoteProperty -Name $item.$Delimiter -Value $tempObject
        }

    }

    $outputObject
}

function Invoke-UnifiRestMethod {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,

        [Parameter(Mandatory)]
        [Uri] $Uri,

        [hashtable] $Body,

        [string] $DownloadFile
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not $Global:UnifiSession) {

        throw 'Unifi not connected. Run Connect-UnifiController to continue.'
    }

    $requestParams = @{
        Uri         = $Uri
        Method      = $Method
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Global:UnifiSession
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {

        $requestParams += @{ SkipCertificateCheck = $true }
    }

    if ($Body) {

        $requestParams += @{ Body = $Body }
    }

    if ($DownloadFile) {

        $requestParams += @{ OutFile = $DownloadFile }
    }

    if ($PSVersionTable.PSVersion.Major -lt 6) {

        $old = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

        try {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [System.Net.Security.RemoteCertificateValidationCallback] { $true }

            $response = Invoke-RestMethod @requestParams
        }
        finally {

            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old
        }
    }
    else {

        $response = Invoke-RestMethod @requestParams
    }

    $response
}

function Invoke-UnifiControllerBackup {

    [CmdletBinding()]
    param (
        [string] $FilePath = ('{0}\{1}' -f $($PWD.Path), $(Get-Date -UFormat '%Y%m%d_%H%M%S'))
    )

    $body = @{
        cmd  = 'backup'
        days = 7
    } | ConvertTo-Json

    $requestParams = @{
        Uri    = ('{0}/api/s/default/cmd/backup' -f $Script:unifiController)
        Method = 'Post'
        Body   = $body
    }

    $response = Invoke-UnifiRestMethod @requestParams

    $backupFileName = ($response.data.url -split '/')[3]

    Write-Host -Object ('Downloading backup file to {0}_{1}' -f $FilePath, $backupFileName)

    $backupRequestParams = @{
        Uri     = ('{0}{1}' -f $Script:unifiController, $response.data.url)
        Method  = 'Get'
        OutFile = ('{0}_{1}' -f $FilePath, $backupFileName)
    }

    $null = Invoke-UnifiRestMethod @backupRequestParams
}

function Get-UnifiSite {

    $requestParams = @{
        Uri    = ('{0}/api/self/sites' -f $Script:unifiController)
        Method = 'Get'
    }

    $response = Invoke-UnifiRestMethod @requestParams

    $response.data
}

function Get-UnifiSiteSetting {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SiteId
    )

    $requestParams = @{
        Uri    = ('{0}/api/s/{1}/rest/setting' -f $Script:unifiController, $SiteId)
        Method = 'Get'
    }

    $response = Invoke-UnifiRestMethod @requestParams

    ConvertTo-UnifiObject -InputObject $response.data -Delimiter 'key'
}

function Get-UnifiSiteHealth {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SiteId
    )

    $requestParams = @{
        Uri    = ('{0}/api/s/{1}/stat/health' -f $Script:unifiController, $SiteId)
        Method = 'Get'
    }

    $response = Invoke-UnifiRestMethod @requestParams

    ConvertTo-UnifiObject -InputObject $response.data -Delimiter 'subsystem'
}

function Get-UnifiSiteDevice {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SiteId,

        [switch] $Detailed
    )

    if ($Detailed) {
        $uri = ('{0}/api/s/{1}/stat/device' -f $Script:unifiController, $SiteId)
    }
    else {
        $uri = ('{0}/api/s/{1}/stat/device-basic' -f $Script:unifiController, $SiteId)
    }

    $requestParams = @{
        Uri    = $uri
        Method = 'Get'
    }

    $response = Invoke-UnifiRestMethod @requestParams

    $response.data
}

function Get-UnifiSiteClient {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SiteId,

        [switch] $Known
    )

    if ($Known) {
        $uri = ('{0}/api/s/{1}/rest/user' -f $Script:unifiController, $SiteId)
    }
    else {
        $uri = ('{0}/api/s/{1}/stat/sta' -f $Script:unifiController, $SiteId)
    }

    $requestParams = @{
        Uri    = $uri
        Method = 'Get'
    }

    $response = Invoke-UnifiRestMethod @requestParams

    $response.data
}

function Get-UnifiDeviceByMAC {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $MacAddress,

        [Parameter(Mandatory)]
        [string] $SiteId
    )

    Get-UnifiSiteDevice -SiteId $SiteId | Where-Object { $_.mac -eq $MacAddress }
}

function Invoke-RebootUnifiDevice {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SiteId,

        [Parameter(Mandatory)]
        [string] $MacAddress
    )

    $body = @{
        mac         = $MacAddress
        reboot_type = 'soft'
        cmd         = 'restart'
    }

    $body = $body | ConvertTo-Json

    $requestParams = @{
        Uri    = ('{0}/api/s/{1}/cmd/devmgr' -f $Script:unifiController, $SiteId)
        Method = 'Post'
        Body   = $body
    }

    $response = Invoke-UnifiRestMethod @requestParams

    $response.data
}
