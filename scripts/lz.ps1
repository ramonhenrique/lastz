param(
  [Parameter(Mandatory)][ValidateSet('shot','click','drag','key','text','limpar')][string]$Action,
  [int]$X, [int]$Y, [int]$X2, [int]$Y2,
  [string]$Out = "C:\lz\shot.png",
  [string]$Key = 'ESC',
  [string]$Text
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
"@
[W]::SetProcessDPIAware() | Out-Null
$p = Get-Process Survival -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$h = $p.MainWindowHandle
if ([W]::IsIconic($h)) { [W]::ShowWindow($h, 9) | Out-Null }
if ([W]::GetForegroundWindow() -ne $h) {
  [W]::keybd_event(0x12, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
  [W]::SetForegroundWindow($h) | Out-Null
  Start-Sleep -Milliseconds 300
  if ([W]::GetForegroundWindow() -ne $h) { [W]::ShowWindow($h, 6) | Out-Null; Start-Sleep -Milliseconds 200; [W]::ShowWindow($h, 9) | Out-Null; [W]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 400 }
  if ([W]::GetForegroundWindow() -ne $h) { throw "Janela do jogo nao ficou em primeiro plano" }
}
Start-Sleep -Milliseconds 150
$r = New-Object W+RECT; [W]::GetClientRect($h, [ref]$r) | Out-Null
$o = New-Object W+POINT; [W]::ClientToScreen($h, [ref]$o) | Out-Null
$w = $r.R - $r.L; $hh = $r.B - $r.T

function Down-Up($sx, $sy) {
  [W]::SetCursorPos($sx, $sy) | Out-Null; Start-Sleep -Milliseconds 60
  [W]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 80
  [W]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
}

switch ($Action) {
  'shot' {
    $pasta = Split-Path $Out; if ($pasta -and -not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($o.X, $o.Y, 0, 0, $bmp.Size)
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    "client ${w}x${hh} at $($o.X),$($o.Y) -> $Out"
  }
  'click' { Down-Up ($o.X + $X) ($o.Y + $Y); "clicked $X,$Y" }
  'drag' {
    [W]::SetCursorPos($o.X + $X, $o.Y + $Y) | Out-Null; Start-Sleep -Milliseconds 60
    [W]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
    for ($i = 1; $i -le 20; $i++) {
      [W]::SetCursorPos([int]($o.X + $X + ($X2 - $X) * $i / 20), [int]($o.Y + $Y + ($Y2 - $Y) * $i / 20)) | Out-Null
      Start-Sleep -Milliseconds 25
    }
    Start-Sleep -Milliseconds 200
    [W]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero); "dragged $X,$Y -> $X2,$Y2"
  }
  # cola o texto no campo que estiver com foco (Ctrl+V); não aperta Enter, quem envia é o clique no botão
  'text' { for ($t = 1; ; $t++) { try { Set-Clipboard -Value $Text -ErrorAction Stop; break } catch { if ($t -ge 8) { throw }; Start-Sleep -Milliseconds 300 } }; Start-Sleep -Milliseconds 150; [W]::keybd_event(0x11, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x56, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x56, 0, 2, [IntPtr]::Zero); [W]::keybd_event(0x11, 0, 2, [IntPtr]::Zero); "colou $($Text.Length) caracteres" }
  # apaga o campo de texto com foco (Ctrl+A e Backspace)
  'limpar' { [W]::keybd_event(0x11, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x41, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x41, 0, 2, [IntPtr]::Zero); [W]::keybd_event(0x11, 0, 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 100; for ($i = 0; $i -lt 3; $i++) { [W]::keybd_event(0x08, 0, 0, [IntPtr]::Zero); [W]::keybd_event(0x08, 0, 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 40 }; 'campo limpo' }
  'key' { $vk = @{ ESC = 0x1B }[$Key]; [W]::keybd_event($vk, 0, 0, [IntPtr]::Zero); [W]::keybd_event($vk, 0, 2, [IntPtr]::Zero); "key $Key" }
}
