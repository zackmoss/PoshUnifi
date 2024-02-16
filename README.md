
# PoshUnifi
PowerShell Module for Self Hosted Unifi Controller

All updates to this repo will be uploaded to the PowerShell Gallery

[PowerShell Gallery Link](https://www.powershellgallery.com/packages/PoshUnifi)

## Install Using PowerShell Gallery
    Install-Module -Name PoshSophos

## Usage
To get started using this module you will need an administrator account on the Self Hosted Unifi controller.

    # Use the Connect-UnifiController command to connect and run subsequent commands
    Connect-UnifiController -ControllerUrl $ControllerUrl -Credential $Credential