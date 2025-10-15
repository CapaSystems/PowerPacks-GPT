function Sleep_Script {
  param (
    [parameter(Mandatory=$true)]
    [int]$Seconds
  )
  $cs.Sys_Sleep($Seconds)
}