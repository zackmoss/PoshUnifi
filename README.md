
# PoshUnifi
[![PSGallery Version](https://img.shields.io/powershellgallery/v/PoshUnifi.png?style=for-the-badge&logo=powershell&label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/PoshUnifi/) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/PoshUnifi.png?style=for-the-badge&label=Downloads)](https://www.powershellgallery.com/packages/PoshUnifi/)

PowerShell Module for Self Hosted Unifi Controller

All updates to this repo will be uploaded to the PowerShell Gallery

## Install Using PowerShell Gallery
    Install-Module -Name PoshUnifi

## Usage
To get started using this module you will need an administrator account on the Self Hosted Unifi controller.

    # Use the Connect-UnifiController command to connect and run subsequent commands
    Connect-UnifiController -ControllerUrl $ControllerUrl -Credential $Credential