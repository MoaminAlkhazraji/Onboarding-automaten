#Hämtar infromation från API.
$uri = "API-Key-Here"
$webRequest = Invoke-WebRequest -Uri $Uri -Method Get
#Gör det in till json fromat.
$webRequest.Content | ConvertFrom-Json
