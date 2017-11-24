<#
.SYNOPSIS
    A set of functions to create, delete or revert to a snapshot of an Azure RM VM
.DESCRIPTION
    A detailed description of the function or script. This keyword can be
    used only once in each topic.
.NOTES
    File Name      : Get-AzureRmBurstApplicability.PS1
    Author         : Dave Hall
    Prerequisite   : PowerShell V5 (Tested with version 5.1 on Windows 10)
                     AzureRM Powershell Module (Tested with version 4.1.0)
    Copyright 2017 - Dave Hall
.LINK
    http://blog.superautomation.co.uk
.EXAMPLE
    PS> . .\Get-AzureRmBurstApplicability -VmName myIdleVm -LastDays 7

    VM myIdleVm Burstable Appplicability:
    B1S   (1 vCPU, 1.00 GiB): Poor Fit
    B2S   (2 vCPU, 4.00 GiB): Possible Fit
    B1MS  (1 vCPU, 2.00 GiB): Poor Fit
    B2MS  (2 vCPU, 8.00 GiB): Possible Fit
    B4MS (4 vCPU, 16.00 GiB): Good Fit
    B8MS (8 vCPU, 32.00 GiB): Good Fit
#>

Param(
    [String]
    $subscriptionName = "Infrastructure",
    
    [Parameter(Mandatory=$True)]
    [String]
    $vmName,

    [Int]
    $lastDays = 7
)

# Ask user to Login to Account
if (!($Account)) {
    Write-Host "Find the login window! :)"
    $Account = Login-AzureRmAccount
}

if ($subscriptionName) {
    $Sub = Select-AzureRmSubscription -SubscriptionName $subscriptionName
    $SubscriptionId = $sub.Subscription.id
} else {
    # Ask user to Select the Subscription
    $Subs = Get-AzureRmSubscription
    Foreach ($Sub in $Subs) {
        $Sub
        $Answer = Read-Host "Use this subscription? [Y/N]"
        if ($Answer -eq "y") {
            $Sub = Select-AzureRmSubscription -SubscriptionId $Sub.Id
            $SubscriptionId = $sub.Subscription.id
            Break
        }
    }
}

if (!($SubscriptionId)) {
    Write-Warning "No Subscription was selected"
    Exit 1
}

$VM = Get-AzureRmVm | Where-Object {$_.Name -eq $vmName}
$VmSku = Get-AzureRmVMSize -Location $vm.Location | 
    Where-Object {$_.Name -eq $vm.HardwareProfile.VmSize}

Write-Host "`nCurrent VM SKU: " -NoNewline
Write-Host $VmSku.Name -ForegroundColor Yellow
$VmSku

$thisVmCoreCount = $VmSku.NumberOfCores

if ($VM.count -ne 1) {
    Write-Error "VM not found or VM name is ambiguous"
}

$endTime = Get-Date
$startTime = $endTime.AddDays(-$lastDays)
$timeGrain = '00:01:00'
$metricName = 'Percentage CPU'

$allowedMetrics = Get-AzureRmMetricDefinition -ResourceId $VM.Id
$cpuMetric = $allowedMetrics | Where-Object {$_.Name.Value -eq $metricName}
if (!($cpuMetric)) {
    Write-Error "Unable to find the $($metricName) metric for the VM"
}

$cpuMetricDetails = Get-AzureRmMetric -ResourceId $VM.id `
    -TimeGrain $timeGrain -StartTime $startTime `
    -EndTime $endTime `
    -MetricNames $cpuMetric.Name.Value

#Quick and dirty code here, assumes single core input VM
$burstStatsArray = Import-CSV .\BurstableCredits.CSV

foreach ($burstableVm in $burstStatsArray) {
    $breaches = 0
    $consumedCredits = 0
    $creditsPerMinute = $burstableVm.CredHr / 60

    foreach ($dataPoint in $cpuMetricDetails.Data) {
        #TODO: Possible Logic error here? maybe not?
        #creditspermin == decimal percent of a single core
        #datapoint.average == percent of all cores
        #thisVmCoreCount == cores on current VM
        #datapoint.average * thisVmCoreCount == percent of single core used, can be over 100

        $bankedCreditsThisDataPoint = `
            $creditsPerMinute - ( ( ($dataPoint.Average * $thisVmCoreCount ) / 100) / $burstableVm.vCPU)

        $consumedCredits += $bankedCreditsThisDataPoint
        if ($consumedCredits -gt $burstableVm.CredMax) {
            $consumedCredits = $burstableVm.CredMax
        }
        if ($consumedCredits -lt 0) {
            $breaches++
            $consumedCredits = 0
            Write-Debug "Calculation as follows:"
            Write-Debug "( ( ($($dataPoint.Average) * $($thisVmCoreCount) ) / 100) / $($burstableVm.vCPU))"
            Write-Debug "bankedCreditsThisDataPoint = $bankedCreditsThisDataPoint"
            Write-Debug "consumedCredits = $consumedCredits"
            Write-Debug "breaches = $breaches"
            Write-Debug "creditsPerMinute = $creditsPerMinute"
            Write-Debug "CPU Percentage = $($dataPoint.Average)"
            Write-Debug "CPU Percentage of single core = $($dataPoint.Average * $thisVmCoreCount)"
            Write-Debug "VM CPUs = $thisVmCoreCount"
            Write-Debug "Burstable SKU CPUs = $($burstableVm.vCPU)"
        }
        if ($bankedCreditsThisDataPoint -lt 0) {

        }
    }
    $burstableVm | Add-Member NoteProperty EndCredits $consumedCredits
    $burstableVm | Add-Member NoteProperty Breaches $breaches
    if ($breaches -eq 0) {
        $fitType = "Good Fit"
    } elseif ( $breaches -lt (10*$lastDays) ) {
        $fitType = "Possible Fit"
    } else {
        $fitType = "Poor Fit"
    }
    $burstableVm | Add-Member NoteProperty Fit $fitType
}

$burstStatsArray | Format-Table -AutoSize