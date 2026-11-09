$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $taskRoot 'functions/.env.local'
$hadFile = Test-Path -LiteralPath $envFile
$previousFile = if ($hadFile) { [System.IO.File]::ReadAllBytes($envFile) } else { $null }
$previousFlag = $env:IQUM_TEST_APP_CHECK
$previousJava = $env:JAVA_HOME
$previousPath = $env:PATH
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
Push-Location $taskRoot
try {
  [System.IO.File]::WriteAllText($envFile, "APP_CHECK_ENFORCED=true`nAPP_CHECK_ALLOWED_APP_IDS=demo-android,demo-ios`n")
  $env:IQUM_TEST_APP_CHECK = '1'
  $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
  $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
  $env:JAVA_TOOL_OPTIONS = '-Xmx512m -XX:ActiveProcessorCount=2'
  # Inspector mode runs the local Functions worker sequentially. Otherwise a
  # burst of emulated Cloud Tasks cold-starts many Node processes on this PC,
  # starving heartbeat requests past the real 15-second disconnect deadline.
  # This suite checks functionality, not production concurrency or latency.
  & "$env:APPDATA\npm\firebase.cmd" emulators:exec --project demo-iqum --only auth,firestore,functions --inspect-functions=9229 'node --test functions/test/emulator.integration.js'
  $testExit = $LASTEXITCODE
} finally {
  if ($hadFile) { [System.IO.File]::WriteAllBytes($envFile, $previousFile) }
  else { Remove-Item -LiteralPath $envFile -ErrorAction SilentlyContinue }
  $env:IQUM_TEST_APP_CHECK = $previousFlag
  $env:JAVA_HOME = $previousJava
  $env:PATH = $previousPath
  $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
  Pop-Location
}
exit $testExit
