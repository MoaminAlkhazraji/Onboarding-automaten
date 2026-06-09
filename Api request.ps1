$uri = "Api here"
$webRequest = Invoke-WebRequest -Uri $Uri -Method Get

$webRequest.Content | ConvertFrom-Json