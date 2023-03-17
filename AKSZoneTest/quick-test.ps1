$url = "http://<put the service external url here>/"
$runTime = [timespan]::FromMinutes(2)

# Make sure to check that it is showing zones and not "Unknown" before running
$stats = @{}
$count = 0
$endTime = [datetime]::Now + $runTime
Write-Host "Running till $endTime ($runTime)"
$ProgressPreference = 'SilentlyContinue'
while ([datetime]::Now -lt $endTime) {
    $res = Invoke-WebRequest -UseBasicParsing -Uri $url
    $zones = [regex]::matches($res.Content, "Zone: ([0-3])") | ForEach-Object { $_.Groups[1].Value }
    $allupLatency = [regex]::match($res.Content, "Called next hop in (\d+)ms").Groups[1].Value
    $azHops = (0..($zones.Count-2) | Where-Object { $zones[$_] -ne $zones[$_+1]}).Count
    if (!$stats.ContainsKey($azHops)) { $stats[$azHops] = @() }
    $stats[$azHops] += $allupLatency
    $count += 1
    Write-Host "$azHops hops ($([string]::Join(" => ", $zones))) in $($allupLatency)ms"
}

Write-Host "Final Stats ($runTime run, $count requests):"
$stats.Keys | Sort-Object | ForEach-Object {
    $measure = $stats[$_] | Measure-Object -Average -Minimum -Maximum
    return [pscustomobject]@{
        CrossAzHops = "$_ az hops"
        AvgLatency = "$([math]::Round($measure.Average, 2))ms"
        MinLatency = "$($measure.Minimum)ms"
        MaxLatency = "$($measure.Maximum)ms"
        Count = $measure.Count
    }
} | Format-Table