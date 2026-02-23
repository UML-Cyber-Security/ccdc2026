Import-Module ActiveDirectory

# List of usernames to exclude
$excludedUsers = @(
    "Administrator",       # Default domain admin
    "svc_account1",        # Example service account
    "john.doe"             # Any other account to exclude
)

# Output file for new passwords if we want it
$logFile = "C:\Users\Administrator\domain_user_passwords.csv"

# Function to generate a 20-character random password
function Generate-RandomPassword {
    param ([int]$length = 20)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
    $charArray = $chars.ToCharArray()
    -join ((1..$length) | ForEach-Object { Get-Random -InputObject $charArray })
}

# Get all enabled domain users
$users = Get-ADUser -Filter * -Properties SamAccountName

foreach ($user in $users) {
    if ($excludedUsers -contains $user.SamAccountName) {
        Write-Host "Skipping excluded user: $($user.SamAccountName)"
        continue
    }

    $newPassword = Generate-RandomPassword

    try {
        Set-ADUser -Identity $user.SamAccountName -PasswordNeverExpires $false
        Set-ADAccountPassword -Identity $user.SamAccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $newPassword -Force)
        Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $true

        "$($user.SamAccountName),$newPassword" | Out-File -FilePath $logFile -Append
        Write-Host "Updated password for $($user.SamAccountName)"
    }
    catch {
        Write-Warning "Failed to update password for $($user.SamAccountName): $_"
    }
}