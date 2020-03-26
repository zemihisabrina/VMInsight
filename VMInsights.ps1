
####################DEMO VM INSIGHTS ########################

        ### prepare variables ###
# Set Azure location for the resources

$location = "westeurope"

# Resource group name
$rgName = "rg-sze"
$rg = Get-AzResourceGroup -Name $rgName

# Get Log Analytics Workspace properties
$law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $rgName

# List all VMs in the resource group 
$azVMs = Get-AzVM -ResourceGroupName $rgName


# Get Log Analytics Workspace's Key
$lawKey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $rgName -Name $law.Name).PrimarySharedKey

#Set in a variable VM Insights solution Name
$SolutionName = "VMInsights"

# List all solutions and their installation status
$solutionStatus = Get-AzOperationalInsightsIntelligencePack -ResourceGroupName $rgName -WorkspaceName $law.Name | Select Name, Enabled | where {$_.Name -eq "VMInsights"}

#Enable VMInsights Solution on the Log Analytics Workspace
Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $rgName -WorkspaceName $law.Name -IntelligencePackName $SolutionName -Enabled $true 


        ### Enable VM Insights on VMs ###
$PublicSettings = @{"workspaceId" = $law.CustomerId}
$ProtectedSettings = @{"workspaceKey" = $lawKey}

# Push Agents Install on VMS to enable VM Insights
foreach ($vm in $azVMs) {
    # get VM's Os type

    $OsType = $vm.StorageProfile.OsDisk.OsType

    # Filter installation extension name by the Os type of the VM
    if($OsType -eq "Windows"){

        Set-AzVMExtension -ExtensionName "MMAExtension" `
            -ResourceGroupName $rgName `
            -VMName $vm.Name `
            -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
            -ExtensionType "MicrosoftMonitoringAgent" `
            -TypeHandlerVersion 1.0 `
            -Settings $PublicSettings `
            -ProtectedSettings $ProtectedSettings `
            -Location $location

        Set-AzVMExtension -ExtensionName "DependencyAgentWindows" `
            -ResourceGroupName $rgName `
            -VMName $vm.Name `
            -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" `
            -ExtensionType "DependencyAgentWindows" `
            -TypeHandlerVersion 9.1 `
            -Settings $PublicSettings `
            -ProtectedSettings $ProtectedSettings `
            -Location $location

    }

    if($OsType -eq "Linux"){

        Set-AzVMExtension -ExtensionName "OMSExtension" `
            -ResourceGroupName $rgName `
            -VMName $vm.Name `
            -Publisher "Microsoft.EnterpriseCloud.Monitoring" `
            -ExtensionType "OmsAgentForLinux" `
            -TypeHandlerVersion 1.0 `
            -Settings $PublicSettings `
            -ProtectedSettings $ProtectedSettings `
            -Location $location

        Set-AzVMExtension -ExtensionName "DependencyAgentLinux" `
            -ResourceGroupName $rgName `
            -VMName $vm.Name `
            -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" `
            -ExtensionType "DependencyAgentLinux" `
            -TypeHandlerVersion 9.1 `
            -Settings $PublicSettings `
            -ProtectedSettings $ProtectedSettings `
            -Location $location

    }

    else{

        Write-Host "OS Type :" -ForegroundColor Red -NoNewline
        Write-Host $OsType -ForegroundColor White -NoNewline
        Write-Host "  not supported " -ForegroundColor Red -NoNewline
    }
            
}

        ### Add Action Group ###

# Add new email where alerts should be send
$email = New-AzActionGroupReceiver -Name "alerts-mail" -EmailReceiver -EmailAddress "PerfAlert@infeeny.com"

# Add Action group
$act = Set-AzActionGroup -Name "performance alerts" -ResourceGroup $rgName -ShortName "perfalerts" -Receiver $email

#$act = Get-AzActionGroup -ResourceGroupName $rgSocleName -Name "plateform alerts Action Group"
$action = New-AzActionGroup -ActionGroupId $act.id

       ### Add metric Rule for CPU ###

#set alert criteria for CPU utilization 
$criteriacpu = New-AzMetricAlertRuleV2Criteria -MetricName "Percentage CPU" `
-TimeAggregation average `
-Operator GreaterThan `
-Threshold 80

#Add alert rule     
Add-AzMetricAlertRuleV2 -Name "Windows and Linux CPU Alerts" `
    -ResourceGroupName $rgName `
    -WindowSize 00:05:00 `
    -Frequency 00:01:00 `
    -TargetResourceScope $rg.ResourceId `
    -Condition $criteriacpu `
    -TargetResourceType microsoft.compute/virtualmachines `
    -TargetResourceRegion $location `
    -ActionGroup $action `
    -Severity 3
