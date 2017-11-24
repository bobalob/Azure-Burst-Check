Import-Module ".\Charting.PSM1"
Function New-BurstChart {
Param(
    [Array]
    $data,

    [Switch]
    $showChart
)
    
    #Format the input data ready to add to a chart
    $baselineDataSet=[ordered]@{}
    $creditsDataSet=[ordered]@{}
    $cpuDataSet=[ordered]@{}

    foreach ($dataPoint in $data) {
        $baselineDataSet.($dataPoint.TimeStamp) = $dataPoint.Baseline
        $creditsDataSet.($dataPoint.TimeStamp) = $dataPoint.Credits
        $cpuDataSet.($dataPoint.TimeStamp) = $dataPoint.CPU
    }

    #Set a suitable Y interval based on the data
    $max = ( @($data.CPU + [int]$data.Baseline[0] + $data.Credits) | Measure-Object -maximum).Maximum

    $yInterval = 10
    if ($max -gt 50) {
        $yInterval = 25
    }
    if ($max -gt 100) {
        $yInterval = 75
    }
    if ($max -gt 400) {
        $yInterval = 125
    }

    # Create chart, add dataset
    $tempChart = New-Chart -Title $data[0].SKU -XInterval 1 -YInterval $yInterval -Width 800
    
    $temp = Add-ChartDataset -Chart $tempChart -Dataset $cpuDataSet -DatasetName "CPU Average (projected as single core)" -SeriesChartType Spline
    $temp = Add-ChartDataset -Chart $tempChart -Dataset $creditsDataSet -DatasetName "Cumulative Credits (percent of max)" -SeriesChartType Spline 
    $temp = Add-ChartDataset -Chart $tempChart -Dataset $baselineDataSet -DatasetName "Baseline CPU"

    #Set line widths and legends
    $temp = $tempChart.Series[0].BorderWidth=5
    $temp = $tempChart.Legends.Add("I_AM_LEGEND")
    
    #Set Docking of the Legend chart
    $temp = $tempChart.Legends[0].DockedToChartArea = $tempChart.ChartAreas[0].Name
    $tempChart.Legends[0].Docking = "Left"

    #Assign the legend to Series.
    $temp = $tempChart.Series[0].Legend = "I_AM_LEGEND"
    $temp = $tempChart.Series[0].IsVisibleInLegend = $true

    $temp = $tempChart.Series[1].BorderWidth=5
    $temp = $tempChart.Series[2].BorderDashStyle="DashDot"
    
    if ($showChart) {
        $tempChart | Show-Chart
    }
    
    # Save the chart as a PNG
    if (!(Test-Path ".\Charts")) {
        New-Item -Path ".\Charts" -ItemType Directory
    }
    $imageName = ".\Charts\$($data[0].SKU).png"
    $temp = $tempChart.SaveImage($imageName, "PNG")
    Write-Host "Chart Created: " -NoNewLine
    Write-Host "$((Get-Childitem $imageName).FullName)" -Foregroundcolor Yellow
}