[CmdletBinding()]
param([Parameter(Mandatory)][string]$BackupPath, [switch]$PassThru)

$ErrorActionPreference = 'Stop'
$resolved = [IO.Path]::GetFullPath($BackupPath)
$errors = [Collections.Generic.List[string]]::new()
$entriesRead = 0
$worldIncluded = $false
$archive = $null
try {
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Backup archive not found: $resolved" }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($resolved)
    $manifestEntry = $archive.GetEntry('backup-manifest.json')
    if (-not $manifestEntry) { $errors.Add('backup-manifest.json is missing') }
    $manifest = $null
    if ($manifestEntry) {
        $reader = [IO.StreamReader]::new($manifestEntry.Open(), [Text.UTF8Encoding]::new($false))
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    }
    $buffer = New-Object byte[] 1048576
    foreach ($entry in $archive.Entries) {
        if (-not $entry.Name) { continue }
        $stream = $entry.Open()
        try { while ($stream.Read($buffer, 0, $buffer.Length) -gt 0) { } } finally { $stream.Dispose() }
        $entriesRead++
    }
    if ($manifest) {
        $worldIncluded = [bool]$manifest.worldIncluded
        $worldLevelDat = $archive.GetEntry("files/$($manifest.worldName)/level.dat")
        if (-not $worldLevelDat) { $worldLevelDat = $archive.GetEntry("files\$($manifest.worldName)\level.dat") }
        if ($worldIncluded -and -not $worldLevelDat) {
            $errors.Add("world is marked included but files/$($manifest.worldName)/level.dat is absent")
        }
    }
} catch {
    $errors.Add($_.Exception.Message)
} finally {
    if ($archive) { $archive.Dispose() }
}
$result = [pscustomobject]@{ valid=($errors.Count -eq 0); archive=$resolved; entriesRead=$entriesRead; worldIncluded=$worldIncluded; errors=@($errors) }
if ($PassThru) { return $result }
if (-not $result.valid) { throw "Backup validation failed: $($result.errors -join '; ')" }
$result | Format-List
