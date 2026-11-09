$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$properties = Join-Path $taskRoot 'android/gradle.properties'
$original = [System.IO.File]::ReadAllBytes($properties)
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
Push-Location $taskRoot
try {
  $content = [System.Text.Encoding]::UTF8.GetString($original)
  $content = $content -replace '(?m)^org.gradle.jvmargs=.*$', 'org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=128m'
  $content += "`norg.gradle.workers.max=1`norg.gradle.parallel=false`norg.gradle.daemon=false`nkotlin.compiler.execution.strategy=in-process`n"
  [System.IO.File]::WriteAllText($properties, $content)
  $env:JAVA_TOOL_OPTIONS = '-XX:ActiveProcessorCount=2'
  & 'C:\Users\HP\flutter\bin\flutter.bat' build apk --debug --target integration_test/app_check_live_test.dart --target-platform android-x64 --dart-define-from-file=output/app-check-live-defines.json
  $buildExit = $LASTEXITCODE
} finally {
  [System.IO.File]::WriteAllBytes($properties, $original)
  $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
  Pop-Location
}
exit $buildExit
