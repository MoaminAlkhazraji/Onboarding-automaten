#Api key
$uri = "API-Key-Here"
#Hemtar infromtion från api.
Invoke-RestMethod -Uri $Uri -Method Get
#Variable för att spara infomationen
$data = Invoke-RestMethod -Uri $Uri -Method Get
