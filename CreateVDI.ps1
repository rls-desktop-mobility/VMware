function CreateVDI {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true,
            ParameterSetName='Standard')]
        [String]
        $Name,

        [Parameter(
            Mandatory=$true,
            ParameterSetName='Standard')]
        [String]
        $DefaultVIServer,

        [Parameter(
            Mandatory=$false,
            ParameterSetName='Standard')]
        [Int]
        $NumCPU,

        [Parameter(
            Mandatory=$false,
            ParameterSetName='Standard')]
        [Int]
        $CoresPerSocket,

        [Parameter(
            Mandatory=$false,
            ParameterSetName='Standard')]
        [Int]
        $MemoryGB,

        [Parameter(
            Mandatory=$true,
            ParameterSetName='Standard')]
        [String]
        $JoinToFQDN,

        [Parameter(
            Mandatory=$false,
            ParameterSetName='Standard')]
        [String]
        $TemplateToUse = 'W10_1809_Template',

        [Parameter(
            Mandatory=$false,
            ParameterSetName='Standard')]
        [Switch]
        $IsRPA

    )
    
    begin {
        Import-Module VMware.PowerCLI

        $VISession = Connect-VIServer -Server $DefaultVIServer -Port 443 -Protocol https -Credential (Get-Credential -Message "Please log into $DefaultVIServer with USERNAME@DOMAIN" -UserName '')
        $VMNameCheck = Get-VM | Where-Object {$_.Name -eq $Name}
        if ($VMNameCheck) {
            Write-Output "There is already a VM with that name, please choose a different one.";break
        }
        if (!$VISession) {
            Write-Output "Unable to Connect to server. Please try again.";break
        }
        switch ($JoinToFQDN) {
            'pvmsd.pactiv.com' { 
                $OSCustomizationSpec = Get-OSCustomizationSpec -Id $JoinToFQDN
                $PortGroup = Get-VDPortGroup -Name 'dvp_vlan_40' -Server $VISession
            }
            'reynoldspkg.rpg.local' {  
                $OSCustomizationSpec = Get-OSCustomizationSpec -Id $JoinToFQDN
                $PortGroup = Get-VDPortGroup -Name 'dvp_vlan_40' -Server $VISession
            }
            'thegc.com' { 
                $OSCustomizationSpec = Get-OSCustomizationSpec -Id $JoinToFQDN 
                $PortGroup = Get-VDPortGroup -Name 'dvp_vlan_402' -Server $VISession
            }
            'everpack.local' { 
                $OSCustomizationSpec = Get-OSCustomizationSpec -Id $JoinToFQDN 
                $PortGroup = Get-VDPortGroup -Name 'dvp_vlan_1151' -Server $VISession
            }
            'reynoldsconsumer.com' {  
                $OSCustomizationSpec = Get-OSCustomizationSpec -Id $JoinToFQDN
                $PortGroup = Get-VDPortGroup -Name 'dvp_vlan_940' -Server $VISession
            }
            Default {Write-Output "Please provide a valid FQDN";break}
        }
    
        $Template = Get-Template -Name $TemplateToUse -Server $VISession
        $DiskStorageFormat = 'Thin'

        $ResourcePool = Get-Cluster -Id 'ClusterComputeResource-domain-c497' -Server $VISession
        $Datastore = Get-Datastore -Server $VISession | Sort-Object -Property 'FreeSpaceGB' -Descending | Select-Object -First 1

        If ($IsRPA.IsPresent){
            $NumCPU = 4
            $CoresPerSocket = 1
            $MemoryGB = 8
        }
    }
    process {

        $NewVMObject = New-VM `
            -Template $Template `
            -Name $Name `
            -OSCustomizationSpec $OSCustomizationSpec `
            -DiskStorageFormat $DiskStorageFormat `
            -ResourcePool $ResourcePool `
            -Datastore $Datastore `
            -Server $VISession
        $NetworkAdapter = Get-NetworkAdapter -VM $NewVMObject -Server $VISession
        Set-NetworkAdapter -NetworkAdapter $NetworkAdapter -Portgroup $PortGroup -Server $VISession -Verbose -Confirm:$false

        If ($IsRPA.IsPresent){
            Write-Host "Upgrading $($NewVMObject.Name) Memory and CPU to RPA Specifications.."
            Set-VM -VM $NewVMObject -MemoryGB $MemoryGB -NumCpu $NumCPU -Confirm:$false | Out-Null
            Write-Host "$($NewVMObject.Name) upgraded: `n    Memory:$($NewVMObject.MemoryGB) `n    CPUs:$($NewVMObject.NumCpu)"
        }
    }
    end {
        Start-VM -VM $NewVMObject -Server $VISession
        Write-Output "$NewVMObject Successfully Created."
    }
}