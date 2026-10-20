param([Parameter(Mandatory = $true)][string]$Stage)

$source = Join-Path $PSScriptRoot '../packages/zig/build.zig'
$present = Test-Path -LiteralPath $source
$metadata = @{
  stage = $Stage
  source = $source
  present = $present
  tracked = (& git ls-files --stage -- packages/zig/build.zig)
  status = (& git status --porcelain -- packages/zig/build.zig)
}
if ($present) {
  $metadata.sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
  $metadata.attributes = (Get-Item -LiteralPath $source).Attributes.ToString()
}
$metadata | ConvertTo-Json -Compress

if (-not $present -and (Get-Command Get-MpThreatDetection -ErrorAction SilentlyContinue)) {
  try {
    Get-MpThreatDetection | Where-Object { $_.Resources -match 'build\.zig' } | ForEach-Object {
      @{
        threatId = $_.ThreatID
        actionSucceeded = $_.ActionSuccess
        detectedAt = $_.InitialDetectionTime
        resources = @($_.Resources | Where-Object { $_ -match 'build\.zig' })
      } | ConvertTo-Json -Compress
    }
  } catch {
    Write-Output "Source security-event inspection unavailable: $($_.Exception.Message)"
  }
}
