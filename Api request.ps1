#Api key
$uri = "API-Key-Here"
#Hemtar infromtion från api.
Invoke-RestMethod -Uri $Uri -Method Get
#Variable för att spara infomationen
$data = Invoke-RestMethod -Uri $Uri -Method Get


#Exemple hur man kan avnända $data variablen.
$data.rowId                    #rowID
$data.firstName                # första namn
$data.lastName                 # sista namn
$data.department               # ex: "ekonomi
$data.manager                  # 

$data[0].rowId                 # första 
$data[1].rowId                 # andra
$data[-1].rowId                # sista
