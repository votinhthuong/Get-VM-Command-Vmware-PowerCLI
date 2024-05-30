# Import PowerCLI Module
Import-Module VMware.PowerCLI

# Define ESXi host
$esxiHost = "IP_Address_of_ESXi_Host"

# Prompt for credentials
$credentials = Get-Credential -Message "Enter your ESXi credentials"

# Connect to ESXi host
Connect-VIServer -Server $esxiHost -Credential $credentials

# Function to get disk provisioning type
function Get-DiskProvisioningType {
    param ($vm)
    
    $disks = Get-HardDisk -VM $vm
    $diskInfo = @()

    foreach ($disk in $disks) {
        $provisioning = switch ($disk.StorageFormat) {
            "Thin" { "Thin" }
            "Thick" {
                if ($disk.EagerlyScrub) {
                    "Thick (Eager Zeroed)"
                } else {
                    "Thick (Lazy Zeroed)"
                }
            }
            default { "Unknown" }
        }
        $diskInfo += "$($disk.Name): $provisioning"
    }

    return $diskInfo -join ", "
}

# Retrieve detailed information including IP addresses, conditional space rounding, adjusted Guest property, and disk provisioning type
$vmList = Get-VM | Select-Object Name, PowerState, 
    @{Name="Notes"; Expression={$_.Notes}},
    @{Name="Guest"; Expression={($_.Guest -split ":", 2)[1].Trim()}},
    NumCpu, CoresPerSocket, MemoryMB, 
    @{Name="MemoryGB"; Expression={"{0:N2}" -f ($_.MemoryMB / 1024)}}, VMHostId, VMHost, VApp, FolderId, Folder, ResourcePoolId, ResourcePool, 
    HARestartPriority, HAIsolationResponse, DrsAutomationLevel, VMSwapfilePolicy, VMResourceConfiguration, Version, HardwareVersion, 
    PersistentId, GuestId, 
    @{Name='UsedSpaceGB'; Expression={
        if ($_.UsedSpaceGB -lt 1000) {
            [math]::Round($_.UsedSpaceGB, 2)
        } else {
            [math]::Round($_.UsedSpaceGB / 1024, 2)
        }
    }}, 
    @{Name='ProvisionedSpaceGB'; Expression={
        if ($_.ProvisionedSpaceGB -lt 1000) {
            [math]::Round($_.ProvisionedSpaceGB, 2)
        } else {
            [math]::Round($_.ProvisionedSpaceGB / 1024, 2)
        }
    }},
    @{Name='DatastoreIdList'; Expression={($_.DatastoreIdList -join ',')}}, 
    CreateDate, SEVEnabled, BootDelayMillisecond, MigrationEncryption, 
    MemoryHotAddEnabled, MemoryHotAddIncrement, MemoryHotAddLimit, CpuHotAddEnabled, CpuHotRemoveEnabled, 
    @{Name='ExtensionData'; Expression={$_ | Select-Object -ExpandProperty ExtensionData | ConvertTo-Json -Depth 10}}, 
    @{Name='CustomFields'; Expression={($_.CustomFields | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '}}, 
    Id, Uid, 
    @{Name="IPAddress"; Expression={($_.Guest.IPAddress -join ", ")}},
    @{Name="DiskProvisioningType"; Expression={Get-DiskProvisioningType $_}}

# Define output path for the CSV file
$outputPath = "C:\your_path\VMs-export.csv"

# Export VM information to CSV
$vmList | Export-Csv -Path $outputPath -NoTypeInformation

# Disconnect from the ESXi server
Disconnect-VIServer -Server $esxiHost -Confirm:$false

Write-Output "VM information exported to $outputPath"
