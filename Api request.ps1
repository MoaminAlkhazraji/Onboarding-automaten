$uri = "https://apod.nasa.gov/apod/image/2606/eagle_1024.jpg"
$webRequest = Invoke-WebRequest -Uri $Uri -Method Get

$webRequest.Content | ConvertFrom-Json
