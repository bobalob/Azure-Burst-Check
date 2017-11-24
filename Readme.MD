# Azure-Burst-Check

Will it burst?

## Get-AzureRmBurstApplicability.PS1

Script to check if your VM is applicable to a burstable VM size. Good for ensuring your VM is idle enough, for enough time that it could run as a burstable machine.

The script will load the VM diagnostics for a specified period and will then do some rudimentary checks to see if it could run in a burstable VM SKU. This script only looks at CPU usage on the host and the memory size of the input VM. It does not take in to account disk or any other resource constraints. Ensure the burstable size shown fits your other requirements before resizing the machine.

Additionally, the script assumes 25% utilisation on a 4-core VM is basically saturating a single core and would be OK on a 1-core VM. The script also assesses all cores as equal, which is not the case in reality - an Av1-Series core is considerably slower than a Dv2-Series core.

The output will show all burstable VM sizes and an applicability rating for the input VM as "Good fit", "Possible fit" and "Poor fit".

The Throttled column shows the amount of data points that would have caused throttling of the VM due to the machine running out of credits. This is a little misleading since if the machine was throttled then it would take longer to do it's work and likely throttle for longer than the figure shows. I would advise if there is any significant (>5%) throttling then the VM size is unsuitable unless the VM is very low priority.

If you do decide to switch to a burstable VM, then I would suggest applying an alert to the new credit metric to show when the VM is running with low credits and increase the VM size accordingly.

## Example

    PS> . .\Get-AzureRmBurstApplicability -VmName myIdleVm -LastDays 7 -ignoreMemory

    Current VM SKU: Standard_A2_v2

    Name           NumberOfCores MemoryInMB MaxDataDiskCount OSDiskSizeInMB ResourceDiskSizeInMB
    ----           ------------- ---------- ---------------- -------------- --------------------
    Standard_A2_v2             2       4096                4        1047552                20480


    Size vCPU MemGB Baseline Max CredHr CredMax EndCredits Throttled Fit
    ---- ---- ----- -------- --- ------ ------- ---------- --------- ---
    B1s  1    1     10       100 6      144              0 33.2 %    Poor Fit
    B1ms 1    2     20       100 12     288            288 0 %       Good Fit
    B2s  2    4     40       200 24     576            576 0 %       Good Fit
    B2ms 2    8     60       200 36     864            864 0 %       Good Fit
    B4ms 4    16    90       400 54     1296          1296 0 %       Good Fit
    B8ms 8    32    135      800 81     1944          1944 0 %       Good Fit

## Notes

The resource usage threshold defaults are a best guess and should be tweaked to your requirements. If you find some better generic thesholds then please post them as an issue or pull request and I'll update them.


## References

https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/virtual-machines-common-b-series-burstable.md#q-how-are-credits-accumulated

https://buildazure.com/2017/09/11/more-affordable-azure-vms-with-burstable-b-series/ 

## Charts

Charting.PSM1 was lifted from this website:

https://goodworkaround.com/2014/06/18/graphing-with-powershell-done-easy/ 