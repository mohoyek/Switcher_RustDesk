Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

param(
  [string]$AppData = $env:APPDATA
)
function Get-ColorFromHex {
  param([string]$hex)
  $hex = $hex.TrimStart('#')
  $r = [convert]::ToInt32($hex.Substring(0,2), 16)
  $g = [convert]::ToInt32($hex.Substring(2,2), 16)
  $b = [convert]::ToInt32($hex.Substring(4,2), 16)
  return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

$darkBg  = Get-ColorFromHex '#2b2b2b'
$darkFg  = Get-ColorFromHex '#ffffff'
$accent  = Get-ColorFromHex '#3a3a3a'
$btnBg   = Get-ColorFromHex '#4a4a4a'
$btnHover= Get-ColorFromHex '#5a5a5a'

# ---------- profiles ----------
$profiles = @(
  @{ Name = 'RustDesk (Default)'; Id = '';                Key = '' },
  @{ Name = 'RaynoDesk';          Id = 'raynodesk.ir';    Key = 'XbWSmwQT8aF9ndM2HGlHGInHXdIcRa4ZbjFBUVx68Mw=' },
  @{ Name = 'AsanDesk';           Id = 'rd.asandesk.ir';  Key = 'joRoqzc0SDOHe61V9WrRORk4PqBVzBntfGtzveM3h8M=' }
)

$configPaths = @(
  "$AppData\RustDesk\config\RustDesk2.toml",
  "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml"
)

# ---------- helpers ----------
function Expand-Path {
  param($p)
  if ($p -like '%APPDATA%*') {
    $p = $p -replace '%APPDATA%', $AppData
  }
  return $p
}

function Read-Current {
  $id = ''; $key = ''
  foreach ($p in $configPaths) {
    $full = Expand-Path $p
    if (-not (Test-Path $full)) { continue }
    $section = ''
    foreach ($l in (Get-Content -LiteralPath $full)) {
      $t = $l.Trim()
      if ($t -match '^\[(.+)\]') { $section = $Matches[1]; continue }
      if ($section -ne 'options') { continue }
      if ($t -match "^custom-rendezvous-server\s*=\s*'(.*)'") { $id = $Matches[1] }
      elseif ($t -match "^key\s*=\s*'(.*)'") { $key = $Matches[1] }
    }
    break
  }
  return @{ Id = $id; Key = $key }
}

function Write-Config($id, $key) {
  foreach ($p in $configPaths) {
    $full = Expand-Path $p
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { continue }
    $lines = @()
    if (Test-Path $full) { $lines = Get-Content -LiteralPath $full }
    $top = @(); $opts = @(); $other = @(); $section = ''
    foreach ($l in $lines) {
      $t = $l.Trim()
      if ($t -match '^\[(.+)\]') { $section = $Matches[1]; if ($section -eq 'options') { continue }; $other += $l; continue }
      if ($section -eq '') {
        if ($t -match '^rendezvous_server\s*=') { continue }
        $top += $l; continue
      }
      if ($section -eq 'options') {
        if ($t -eq '[options]') { continue }
        if ($t -match '^(custom-rendezvous-server|key|relay-server|api-server)\s*=') { continue }
        $opts += $l; continue
      }
      $other += $l
    }
    $new = @()
    $new += $top
    $new += '[options]'
    $new += "custom-rendezvous-server = '$id'"
    $new += "key = '$key'"
    $new += "relay-server = ''"
    $new += "api-server = ''"
    $new += $opts
    $new += $other
    [IO.File]::WriteAllLines($full, $new, (New-Object System.Text.UTF8Encoding $false))
  }
}

function Stop-RustDesk {
  Get-Service -Name RustDesk -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
  Get-Process -Name rustdesk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Start-RustDesk {
  Get-Service -Name RustDesk -ErrorAction SilentlyContinue | Start-Service -ErrorAction SilentlyContinue
}

function Launch-RustDesk {
  $exe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
  if (Test-Path $exe) {
    $ws = New-Object -ComObject WScript.Shell
    $ws.Run("""$exe""", 0, $false)
  }
}

function Append-Log {
  param($msg)
  $ts = Get-Date -Format 'HH:mm:ss'
  $script:logBox.AppendText("[$ts] $msg`r`n")
  $script:logBox.SelectionStart = $script:logBox.TextLength
  $script:logBox.ScrollToCaret()
}

function Apply-Profile($pr) {
  $script:statusLabel.Text = "Applying $($pr.Name)..."
  Append-Log "Applying $($pr.Name)..."

  Stop-RustDesk
  Append-Log 'Service stopped'

  try {
    Write-Config $pr.Id $pr.Key
    Append-Log 'Config written'
  } catch {
    $script:statusLabel.Text = "Write error: $_"
    Append-Log "Write error: $_"
    return
  }

  Start-RustDesk
  Append-Log 'Service started'

  Launch-RustDesk
  Append-Log 'RustDesk launched'

  $script:statusLabel.Text = "Done. Active: $($pr.Name)"
  Append-Log "Done. Active: $($pr.Name)"
}

# ---------- UI ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'RustDesk Server Switcher'
$form.Size = New-Object System.Drawing.Size(600, 600)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = $darkBg
$form.ForeColor = $darkFg

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'RustDesk Server Switcher'
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(190, 20)
$titleLabel.ForeColor = $darkFg

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = 'Select a server'
$statusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(205, 60)
$statusLabel.ForeColor = $darkFg
$script:statusLabel = $statusLabel

$btnPanel = New-Object System.Windows.Forms.Panel
$btnPanel.Size = New-Object System.Drawing.Size(560, 60)
$btnPanel.Location = New-Object System.Drawing.Point(20, 100)
$btnPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)

$btnDefault = New-Object System.Windows.Forms.Button
$btnDefault.Text = 'RustDesk (Default)'
$btnDefault.Size = New-Object System.Drawing.Size(160, 40)
$btnDefault.Location = New-Object System.Drawing.Point(0, 10)
$btnDefault.BackColor = $btnBg
$btnDefault.ForeColor = $darkFg
$btnDefault.FlatStyle = 'Flat'
$btnDefault.FlatAppearance.BorderSize = 0
$btnDefault.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDefault.Add_Click({ Apply-Profile $profiles[0] })

$btnRayno = New-Object System.Windows.Forms.Button
$btnRayno.Text = 'RaynoDesk'
$btnRayno.Size = New-Object System.Drawing.Size(160, 40)
$btnRayno.Location = New-Object System.Drawing.Point(200, 10)
$btnRayno.BackColor = $btnBg
$btnRayno.ForeColor = $darkFg
$btnRayno.FlatStyle = 'Flat'
$btnRayno.FlatAppearance.BorderSize = 0
$btnRayno.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRayno.Add_Click({ Apply-Profile $profiles[1] })

$btnAsan = New-Object System.Windows.Forms.Button
$btnAsan.Text = 'AsanDesk'
$btnAsan.Size = New-Object System.Drawing.Size(160, 40)
$btnAsan.Location = New-Object System.Drawing.Point(400, 10)
$btnAsan.BackColor = $btnBg
$btnAsan.ForeColor = $darkFg
$btnAsan.FlatStyle = 'Flat'
$btnAsan.FlatAppearance.BorderSize = 0
$btnAsan.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnAsan.Add_Click({ Apply-Profile $profiles[2] })

$btnPanel.Controls.AddRange(@($btnDefault, $btnRayno, $btnAsan))

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = 'Log:'
$logLabel.AutoSize = $true
$logLabel.Location = New-Object System.Drawing.Point(20, 170)
$logLabel.ForeColor = $darkFg

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Size = New-Object System.Drawing.Size(560, 380)
$logBox.Location = New-Object System.Drawing.Point(20, 190)
$logBox.BackColor = $accent
$logBox.ForeColor = $darkFg
$logBox.ReadOnly = $true
$logBox.BorderStyle = 'FixedSingle'
$script:logBox = $logBox

$form.Controls.AddRange(@($titleLabel, $statusLabel, $btnPanel, $logLabel, $logBox))

$form.Add_Shown({
  $cur = Read-Current
  $curName = $null
  foreach ($pr in $profiles) {
    if ($pr.Id -eq $cur.Id -and $pr.Key -eq $cur.Key) { $curName = $pr.Name }
  }
  if ($curName) {
    $script:statusLabel.Text = "Current: $curName"
  } else {
    $script:statusLabel.Text = "Current: Custom ($($cur.Id))"
  }
})

[System.Windows.Forms.Application]::Run($form)
