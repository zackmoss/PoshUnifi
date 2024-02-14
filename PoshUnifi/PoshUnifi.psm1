
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

    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    if (!$Refresh) {

        $Script:unifiController = ('{0}:{1}' -f $ControllerUrl, $ControllerPort)

        $loginUri = ('{0}:{1}/api/login' -f $ControllerUrl, $ControllerPort)

        $Script:unifiCredential = $Credential
    }

    $body = @{
        username = $Script:unifiCredential.UserName
        password = $Script:unifiCredential.GetNetworkCredential().Password
    }

    $body = $body | ConvertTo-Json

    try {

        $response = Invoke-RestMethod `
            -Uri $LoginURI `
            -Method Post `
            -Body $body `
            -ContentType 'application/json; charset=utf-8' `
            -SessionVariable unifiSession `
            -ErrorAction Stop
    
        if ($response.meta.rc -eq 'ok') {
    
            $Script:Session = $unifiSession
        }
    }
    catch {
    
        Write-Error -Message ('API Connection Error: {0}' -f $_.Exception.Message)
    }
}

function Invoke-UnifiControllerBackup {

    $body = @{
        cmd  = 'async-backup'
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

        $response.data
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams

                $response.data
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams

                $response.data
            }
            default {

                Write-Error -Message ('API Connection Error: {0}' -f $_.Exception.Message)
            }
        }
    }
}

function Get-UnifiSite {

    $requestParams = @{
        Uri         = ('{0}/api/self/sites' -f $Script:unifiController)
        Method      = 'Get'
        ContentType = 'application/json; charset=utf-8'
        WebSession  = $Script:Session
        ErrorAction = 'Stop'
    }

    try {

        $response = Invoke-RestMethod @requestParams

        $response.data
    }
    catch {

        switch ($_.Exception.Message) {

            'The remote server returned and error: (401) Unauthorized.' {

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams

                $response.data
            }
            'The underlying connection was closed: An unexpected error occurred on a send.' {

                Connect-UnifiController -Refresh

                $response = Invoke-RestMethod @requestParams

                $response.data
            }
            default {

                Write-Error -Message ('API Connection Error: {0}' -f $_.Exception.Message)
            }
        }
    }
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

                Write-Error -Message ('API Connection Error: {0}' -f $_.Exception.Message)
            }
        }
    }

    $response.data
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

                Write-Error -Message ('API Connection Error: {0}' -f $_.Exception.Message)
            }
        }
    }

    $response.data
}
