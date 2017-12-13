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
    PS> . .\Get-AzureRmBurstApplicability -VmName myIdleVm -LastDays 7 -ignoreMemory

    Current VM SKU: Standard_A2_v2

    Name           NumberOfCores MemoryInMB MaxDataDiskCount OSDiskSizeInMB ResourceDiskSizeInMB
    ----           ------------- ---------- ---------------- -------------- --------------------
    Standard_A2_v2             2       4096                4        1047552                20480



    Size vCPU MemGB Baseline Max CredHr CredMax EndCredits Breaches Fit
    ---- ---- ----- -------- --- ------ ------- ---------- -------- ---
    B1s  1    1     10       100 6      144              0     3328 Poor Fit
    B1ms 1    2     20       100 12     288            288        0 Good Fit
    B2s  2    4     40       200 24     576            576        0 Good Fit
    B2ms 2    8     60       200 36     864            864        0 Good Fit
    B4ms 4    16    90       400 54     1296          1296        0 Good Fit
    B8ms 8    32    135      800 81     1944          1944        0 Good Fit
#>

Param(
    [String]
    $subscriptionName,
    
    [Parameter(Mandatory=$True)]
    [String]
    $vmName,

    [Int]
    $lastDays = 7,

    [Switch]
    $ignoreMemory,

    [PSCredential]
    $Credential,

    [Switch]
    $showChart
)

# Ask user to Login to Account
if (!($Account)) {
    if (!($Credential)) {
        Write-Host "Find the login window :)"
        $Account = Login-AzureRmAccount
    } else {
        $Account = Login-AzureRmAccount -Credential $Credential
    }
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

if ($VM.count -ne 1) {
    Write-Error "VM not found or VM name is ambiguous"
    Exit 1
} else {
    Write-Host "Found VM as follows:" -ForegroundColor Yellow
    Write-Host "VM ID: $($VM.Id)"
}

$VmSku = Get-AzureRmVMSize -Location $vm.Location | 
    Where-Object {$_.Name -eq $vm.HardwareProfile.VmSize}

Write-Host "`nCurrent VM SKU: " -NoNewline
Write-Host $VmSku.Name -ForegroundColor Yellow
$VmSku

$thisVmCoreCount = $VmSku.NumberOfCores


$endTime = Get-Date
$startTime = $endTime.AddDays(-$lastDays)
$timeGrain = '00:01:00'
$metricName = 'Percentage CPU'

$allowedMetrics = Get-AzureRmMetricDefinition -ResourceId $VM.Id
$cpuMetric = $allowedMetrics | Where-Object {$_.Name.Value -eq $metricName}
if (!($cpuMetric)) {
    Write-Error "Unable to find the $($metricName) metric for the VM"
    Exit 1
}

$cpuMetricDetails = Get-AzureRmMetric -ResourceId $VM.id `
    -TimeGrain $timeGrain -StartTime $startTime `
    -EndTime $endTime `
    -MetricNames $cpuMetric.Name.Value

$timeGrain = '01:00:00'
$cpuMetricHours = Get-AzureRmMetric -ResourceId $VM.id `
    -TimeGrain $timeGrain -StartTime $startTime `
    -EndTime $endTime `
    -MetricNames $cpuMetric.Name.Value

$burstStatsArray = Import-CSV .\BurstableCredits.CSV
$chartData = @{}

foreach ($burstableVm in $burstStatsArray) {
    $breaches = 0
    $consumedCredits = 0
    $creditsPerMinute = $burstableVm.CredHr / 60
    $vmChartData = @()
    $dataCounter = 0

    foreach ($dataPoint in $cpuMetricDetails.Data) {
        #TODO: Possible Logic error here? Seems to work OK
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
        }
        if ($bankedCreditsThisDataPoint -lt 0) {

        }
        if (($dataCounter % 60) -eq 0) {
            $chartDataPoint = "" | Select-Object SKU, TimeStamp, Baseline, Credits, CPU
            $chartDataPoint.SKU = "$($vmName) as $($burstableVm.Size)"
            $chartDataPoint.TimeStamp = $dataPoint.TimeStamp
            $chartDataPoint.Baseline = [Int]$burstableVm.Baseline
            $chartDataPoint.Credits = [Float] (($consumedCredits / $burstableVm.CredMax) * 100)
            $chartDataPoint.CPU = [Float] (($cpuMetricHours.Data[$dataCounter/60]).Average * $thisVmCoreCount)
            $vmChartData += $chartDataPoint
        }
        $dataCounter++
    }
    
    $percentThrottled = $breaches / $cpuMetricDetails.Data.Count * 100

    $burstableVm | Add-Member NoteProperty EndCredits ([Int]$consumedCredits)
    $burstableVm | Add-Member NoteProperty Throttled "$([Math]::Round($percentThrottled,1)) %"

    if ($breaches -eq 0) {
        $fitType = "Good Fit"
    } elseif ( $breaches -lt (10*$lastDays) ) {
        $fitType = "Possible Fit"
    } else {
        $fitType = "Poor Fit"
    }
    $burstableVm | Add-Member NoteProperty Fit $fitType
    $burstableVm | Add-Member NoteProperty Breaches $breaches
    $chartData.($burstableVm.Size) = $vmChartData
}

if ($ignoreMemory) {
    $burstStatsArray | Select-Object * | Format-Table -AutoSize
} else {
    $burstStatsArray | 
        Where-Object {[Int]$_.MemGB -ge $VmSku.MemoryInMB/1024} | Format-Table -AutoSize
}

. .\Chart-Function.PS1
foreach ($vmSku in $burstStatsArray) {
    . New-BurstChart -data $chartData.($VmSku.Size) -showChart:$showChart
}
