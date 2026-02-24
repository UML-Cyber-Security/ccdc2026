# List of local usernames to exclude
$excludedUsers = @(
    "Administrator",  # Default local admin
    "Guest",          # Default guest account
    "svc_local"       # Example service account
)

# Output file for new passwords
$logFile = "C:\Users\Administrator\local_user_passwords.csv"
"Username,NewPassword" | Out-File -FilePath $logFile

# Function to generate a 20-character random password
function Generate-RandomPassword {
    param ([int]$length = 20)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
    $charArray = $chars.ToCharArray()
    -join ((1..$length) | ForEach-Object { Get-Random -InputObject $charArray })
}

# Get all local users
$localUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

foreach ($user in $localUsers) {
    if ($excludedUsers -contains $user.Name) {
        Write-Host "Skipping excluded user: $($user.Name)"
        continue
    }

    $newPassword = Generate-RandomPassword

    try {
        $securePassword = ConvertTo-SecureString -String $newPassword -AsPlainText -Force
        Set-LocalUser -Name $user.Name -Password $securePassword

        "$($user.Name),$newPassword" | Out-File -FilePath $logFile -Append
        Write-Host "Updated password for $($user.Name)"
    }
    catch {
        Write-Warning "Failed to update password for $($user.Name): $_"
    }
}