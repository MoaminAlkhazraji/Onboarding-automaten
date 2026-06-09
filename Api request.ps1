$uri = "https://script.google.com/macros/s/AKfycbwFnx_-ZwAeEszfJ9Z72MDfkRddqQsNiVbt6VAlIPftcpvf9zFkYYy8UzYkFV-BPwU/exec?token=ITSEC2026-onboarding-test-token"
$webRequest = Invoke-WebRequest -Uri $Uri -Method Get

$webRequest.Content | ConvertFrom-Json
