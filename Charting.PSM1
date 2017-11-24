# Charting.PSM1 from https://goodworkaround.com/2014/06/18/graphing-with-powershell-done-easy/ 

# Load assembly for Microsoft Chart Controls for Microsoft .NET Framework 3.5
Write-Verbose "Loading assemblies"
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
 
 
function New-Chart
{
    [CmdletBinding()]
    [OutputType([System.Windows.Forms.DataVisualization.Charting.ChartArea])]
    Param
    (
        # Dataset
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=0)]
        $Dataset,
 
        # Width
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [int]$Width = 500,
 
        # Height
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [int]$Height = 500,
 
        # X Interval
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [int]$XInterval,
 
        # Y Interval
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [int]$YInterval,
 
        # X Title
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [string]$XTitle,
 
        # Y Title
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [string]$YTitle,
 
        # Title
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false)]
        [string]$Title
 
 
    )
 
    # Create chart
    Write-Verbose "Creating chart $Width x $Height"
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $Chart.Width = $Width
    $Chart.Height = $Height
    $Chart.Left = 0
    $Chart.Top = 0
 
    # Add chart area to chart
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $Chart.ChartAreas.Add($ChartArea)
 
    # Set titles and lables
    if($Title) {
        Write-Verbose "Setting title: $Title"
        [void]$Chart.Titles.Add($Title)
    } else {
        Write-Verbose "No title provided"
    }
 
    if($YTitle) {
        Write-Verbose "Setting Ytitle: $YTitle"
        $ChartArea.AxisY.Title = $YTitle
    } else {
        Write-Verbose "No Ytitle provided"
    }
 
    if($XTitle) {
        Write-Verbose "Setting Xtitle: $XTitle"
        $ChartArea.AxisX.Title = $XTitle
    } else {
        Write-Verbose "No Xtitle provided"
    }
 
    if($YInterval) {
        Write-Verbose "Setting Y Interval to $YInterval"
        $ChartArea.AxisY.Interval = $YInterval
    }
 
    if($XInterval) {
        Write-Verbose "Setting X Interval to $XInterval"
        $ChartArea.AxisX.Interval = $XInterval
    }
 
    if($Dataset) {
        Write-Verbose "Dataset provided. Adding this as ""default dataset"" with chart type line."
        [void]$Chart.Series.Add("default dataset")
        $Chart.Series["default dataset"].Points.DataBindXY($Dataset.Keys, $Dataset.Values)
        $Chart.Series["default dataset"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    }
 
    return $Chart
}
 
 
 
 
function Add-ChartDataset
{
    [CmdletBinding()]
    [OutputType([System.Windows.Forms.DataVisualization.Charting.ChartArea])]
    Param
    (
        # Chart
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $Chart,
 
        # Dataset
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$false,
                   Position=0)]
        $Dataset,
 
        # DatasetName
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=1)]
        [string]$DatasetName = "Added dataset",
 
        # SeriesChartType = http://msdn.microsoft.com/en-us/library/system.windows.forms.datavisualization.charting.seriescharttype(v=vs.110).aspx
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=2)]
        [string]$SeriesChartType = "Line"
    )
 
    Write-Verbose "Adding series $Datasetname"
    [void]$Chart.Series.Add($DatasetName)
 
    Write-Verbose "Adding data binding"
    $Chart.Series[$DatasetName].Points.DataBindXY($Dataset.Keys, $Dataset.Values)
 
    Write-Verbose "Setting chart type to $SeriesChartType"
    $Chart.Series[$DatasetName].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::$SeriesChartType
 
    return $Chart
}
 
 
 
 
 
function Show-Chart
{
    [CmdletBinding()]
    [OutputType([void])]
    Param
    (
        # Chart
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $Chart
    )
 
    # display the chart on a form
    $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $Form = New-Object Windows.Forms.Form
    $Form.Text = "PowerShell Chart"
    $Form.Width = $chart.Width
    $Form.Height = $chart.Height + 50
    $Form.controls.add($Chart)
    $Form.Add_Shown({$Form.Activate()})
    $Form.ShowDialog() | Out-Null
}