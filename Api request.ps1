$uri = "API-Key-Here"
$webRequest = Invoke-WebRequest -Uri $Uri -Method Get

$webRequest.Content | ConvertFrom-Json
