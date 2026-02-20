#!/usr/bin/env pwsh
<#
Git passes:
  $args[0] = base
  $args[1] = ours
  $args[2] = theirs
  $args[3] = merged output file
#>

$base = $args[0]
$ours = $args[1]
$theirs = $args[2]
$merged = $args[3]

# Accept incoming changes → copy "theirs" to the merge result
Copy-Item -LiteralPath $theirs -Destination $merged -Force

exit 0
