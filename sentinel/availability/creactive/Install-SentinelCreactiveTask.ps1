param(
  [string]$WslDistribution = 'Ubuntu',
  [string]$TaskName = 'ASCENDA Sentinel Local Observer',
  [switch]$PlanOnly,
  [switch]$StartNow
)

$ErrorActionPreference = 'Stop'
$wsl = "$env:WINDIR\System32\wsl.exe"
if (-not (Test-Path $wsl)) { throw 'WSL_NOT_FOUND' }

$linuxCommand = '~/.local/share/ascenda-sentinel/availability/runtime/start-observer.sh'
$arguments = "-d $WslDistribution -- bash -lc `"$linuxCommand`""

$plan = [ordered]@{
  schema_version = 'sentinel-creactive-autostart/v1'
  task_name = $TaskName
  trigger = 'AtLogOn'
  executable = $wsl
  arguments = $arguments
  wsl_distribution = $WslDistribution
  secrets = $false
  highest_privileges = $false
  multiple_instances = 'IgnoreNew'
  start_now = [bool]$StartNow
}

if ($PlanOnly) {
  $plan.status = 'PLAN_ONLY'
  $plan | ConvertTo-Json -Depth 4
  exit 0
}

$action = New-ScheduledTaskAction -Execute $wsl -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
if ($task.TaskName -ne $TaskName) { throw 'TASK_REGISTRATION_FAILED' }

if ($StartNow) {
  Start-ScheduledTask -TaskName $TaskName
  Start-Sleep -Seconds 2
}

$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
$plan.status = 'REGISTERED'
$plan.task_state = (Get-ScheduledTask -TaskName $TaskName).State.ToString()
$plan.last_task_result = $taskInfo.LastTaskResult
$plan | ConvertTo-Json -Depth 4
