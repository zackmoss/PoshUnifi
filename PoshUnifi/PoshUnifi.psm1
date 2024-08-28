
function Connect-UnifiController {

    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Connect', Mandatory)]
        [string] $ControllerUrl,

        [Parameter(ParameterSetName = 'Connect')]
        [string] $ControllerPort = '8443',

        [Parameter(ParameterSetName = 'Connect', Mandatory)]
        [pscredential] $Credential,

        [Parameter(ParameterSetName = 'Refresh')]
        [switch] $Refresh
    )

    $currentProtocol = [Net.ServicePointManager]::SecurityProtocol

    if ($currentProtocol.ToString().Split(',').Trim() -notcontains 'Tls12') {

        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    Add-Type -TypeDefinition @'
using System.Net;
using System.Security.Cryptography.X509Certificates;

public class InSecureWebPolicy : ICertificatePolicy
{
    public bool CheckValidationResult(ServicePoint sPoint, X509Certificate cert,WebRequest wRequest, int certProb)
    {
        return true;
    }
}
'@

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName InSecureWebPolicy

    if (!$Refresh) {

        $Script:unifiController = ('{0}:{1}' -f $ControllerUrl, $ControllerPort)

        $Script:loginUri = ('{0}:{1}/api/login' -f $ControllerUrl, $ControllerPort)

        $Script:unifiCredential = $Credential
    }

    $body = @{
        username = $Script:unifiCredential.UserName
        password = $Script:unifiCredential.GetNetworkCredential().Password
    }

    $body = $body | ConvertTo-Json

    try {

        $response = Invoke-RestMethod `
            -Uri $Script:loginUri `
            -Method Post `
            -Body $body `
            -ContentType 'application/json; charset=utf-8' `
            -SessionVariable unifiSession `
            -ErrorAction Stop

        if ($response.meta.rc -eq 'ok') {

            Write-Verbose -Message ('Connection successful to controller {0}' -f $Script:unifiController)

            $Script:Session = $unifiSession
        }
    }
    catch {

        throw ('API Connection Error: {0}' -f $_.Exception.Message)
    }
}

function Invoke-UnifiControllerBackup {

    [CmdletBinding()]
    param (
        [string] $FilePath = ('{0}\{1}' -f $($PWD.Path), $(Get-Date -UFormat '%Y%m%d_%H%M%S'))
    )

    $body = @{
        cmd  = 'backup'
        days = 7
    }

    $body = $body | ConvertTo-Json

    $requestParams = @{
        Uri         = ('{0}/api/s/default/cmd/backup' -f $Script:unifiController)
        Method      = 'Post'
        Body        = $body
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'Stop'
    }

    try {

        $response = Invoke-RestMethod @requestParams
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            default {

                throw 'API Connection Error: Please run Connect-UnifiController to run this command.'
            }
        }
    }

    $backupFileName = ($response.data.url -split '/')[3]

    Write-Host -Object ('Downloading backup file to {0}_{1}' -f $FilePath, $backupFileName)

    $null = Invoke-WebRequest `
        -Uri ('{0}{1}' -f $Script:unifiController, $response.data.url) `
        -Method Get -OutFile ('{0}_{1}' -f $FilePath, $backupFileName) `
        -WebSession $Script:Session
}

function Get-UnifiSite {

    [CmdletBinding()]
    param ()

    $requestParams = @{
        Uri         = ('{0}/api/self/sites' -f $Script:unifiController)
        Method      = 'Get'
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'Stop'
    }

    try {

        $response = Invoke-RestMethod @requestParams
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            default {

                throw 'API Connection Error: Please run Connect-UnifiController to run this command.'
            }
        }
    }

    $response.data
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
        Uri         = $uri
        Method      = 'Get'
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'Stop'
    }

    try {

        $response = Invoke-RestMethod @requestParams
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            default {

                throw 'API Connection Error: Please run Connect-UnifiController to run this command.'
            }
        }
    }

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
        Uri         = $uri
        Method      = 'Get'
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'SilentlyContinue'
    }

    try {

        $response = Invoke-RestMethod @requestParams
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            default {

                throw 'API Connection Error: Please run Connect-UnifiController to run this command.'
            }
        }
    }

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
        Uri         = ('{0}/api/s/{1}/cmd/devmgr' -f $Script:unifiController, $SiteId)
        Method      = 'Post'
        Body        = $body
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'Stop'
    }

    try {

        $response = Invoke-RestMethod @requestParams
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Write-Verbose -Message 'Cookie invalid, refreshing connection'

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams
            }
            default {

                throw 'API Connection Error: Please run Connect-UnifiController to run this command.'
            }
        }
    }

    $response.data
}
