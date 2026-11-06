# 追平 · 桌面常驻小工具（PowerShell + WPF，无依赖）
# 用法：双击同目录的 追平.vbs（无黑窗），或 powershell -File zhuiping.ps1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:DataFile = Join-Path $Root 'zhuiping.json'

$script:Cfg = @{
  monthlySalary = 20000; workDays = 21.75; hoursPerDay = 8; tokenPrice = 1
}
$script:State = @{
  day = ''; workedSec = 0; startedAt = 0; month = ''; tokens = 0; tokenAt = 0
}

function Get-DayKey { (Get-Date).ToString('yyyy-MM-dd') }
function Get-MonthKey { (Get-Date).ToString('yyyy-MM') }

function Load-Data {
  if ($script:State.Loaded) { return }
  $script:State.Loaded = $true
  if (-not (Test-Path $script:DataFile)) { return }
  try {
    $j = Get-Content -Raw -Encoding UTF8 $script:DataFile | ConvertFrom-Json
    foreach ($k in 'monthlySalary', 'workDays', 'hoursPerDay', 'tokenPrice') {
      if ($null -ne $j.cfg.$k) { $script:Cfg[$k] = [double]$j.cfg.$k }
    }
    if ($j.day) { $script:State.day = [string]$j.day }
    if ($null -ne $j.workedSec) { $script:State.workedSec = [double]$j.workedSec }
    if ($null -ne $j.startedAt) { $script:State.startedAt = [double]$j.startedAt }
    if ($j.month) { $script:State.month = [string]$j.month }
    if ($null -ne $j.tokens) { $script:State.tokens = [double]$j.tokens }
    if ($null -ne $j.tokenAt) { $script:State.tokenAt = [double]$j.tokenAt }
  } catch { }
}

function Save-Data {
  $o = [ordered]@{
    cfg = [ordered]@{
      monthlySalary = $script:Cfg.monthlySalary; workDays = $script:Cfg.workDays
      hoursPerDay = $script:Cfg.hoursPerDay; tokenPrice = $script:Cfg.tokenPrice
    }
    day = $script:State.day; workedSec = $script:State.workedSec
    startedAt = $script:State.startedAt; month = $script:State.month
    tokens = $script:State.tokens; tokenAt = $script:State.tokenAt
  }
  try { ($o | ConvertTo-Json -Depth 4) | Set-Content -Encoding UTF8 $script:DataFile } catch { }
}

function Get-EpochMs([datetime]$d) { [double]([DateTimeOffset]::new($d)).ToUnixTimeMilliseconds() }

Load-Data
if ($script:State.day -ne (Get-DayKey)) {
  $script:State.day = Get-DayKey; $script:State.workedSec = 0; $script:State.startedAt = 0
}
if ($script:State.month -ne (Get-MonthKey)) {
  $script:State.month = Get-MonthKey; $script:State.tokens = 0; $script:State.tokenAt = (Get-EpochMs (Get-Date))
}

# ---------------- 计算 ----------------
function Get-SalaryPerSec {
  if ($script:Cfg.workDays -le 0 -or $script:Cfg.hoursPerDay -le 0) { return 0 }
  $script:Cfg.monthlySalary / ($script:Cfg.workDays * $script:Cfg.hoursPerDay * 3600)
}
function Get-ElapsedSec {
  $s = $script:State.workedSec
  if ($script:State.startedAt -gt 0) { $s += ((Get-EpochMs (Get-Date)) - $script:State.startedAt) / 1000 }
  $s
}
function Get-TokenStats {
  if ($script:State.tokens -le 0) { return $null }
  $at = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$script:State.tokenAt).LocalDateTime
  $start = [datetime]::new($at.Year, $at.Month, 1)
  $days = ($at - $start).TotalDays
  if ($days -lt 1) { return $null }
  $perDay = $script:State.tokens / $days
  $perSec = $perDay / 86400
  [pscustomobject]@{
    days = $days; perDay = $perDay; perSec = $perSec
    yuanPerSec = $perSec * $script:Cfg.tokenPrice / 1000000
    yuanPerHour = $perSec * 3600 * $script:Cfg.tokenPrice / 1000000
  }
}
function Format-Money($v, $d = 2) { $v.ToString("N$d") }

# ---------------- 界面 ----------------
$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'
$win.AllowsTransparency = $true
$win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true
$win.ShowInTaskbar = $false
$win.SizeToContent = 'WidthAndHeight'
$win.ResizeMode = 'NoResize'

$xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        CornerRadius="14" BorderThickness="1" BorderBrush="#33FFFFFF" Padding="16,12,16,12">
  <Border.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#F21B1F23" Offset="0"/>
      <GradientStop Color="#F214171A" Offset="1"/>
    </LinearGradientBrush>
  </Border.Background>
  <StackPanel Width="238">
    <DockPanel LastChildFill="False">
      <TextBlock x:Name="Title" DockPanel.Dock="Left" Text="追平" Foreground="#E8E4DC"
                 FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
      <TextBlock x:Name="Clock" DockPanel.Dock="Right" Text="--:--:--" Foreground="#6B7178"
                 FontSize="10" FontFamily="Consolas" VerticalAlignment="Center"/>
    </DockPanel>
    <TextBlock x:Name="Money" Text="¥0.00" Foreground="#FF5A1F" FontSize="34"
               FontFamily="Consolas" FontWeight="Bold" Margin="0,6,0,0"/>
    <TextBlock x:Name="Sub" Text="未开工" Foreground="#9AA0A6" FontSize="10"
               FontFamily="Consolas" Margin="0,2,0,8"/>
    <Border Height="1" Background="#22FFFFFF" Margin="0,0,0,8"/>
    <TextBlock Text="今日 token 花费 · 推算" Foreground="#6B7178" FontSize="9"/>
    <TextBlock x:Name="Burn" Text="—" Foreground="#5FD3C4" FontSize="20"
               FontFamily="Consolas" FontWeight="Bold" Margin="0,2,0,0"/>
    <TextBlock x:Name="BurnSub" Text="未填写本月总额" Foreground="#6B7178" FontSize="9"
               FontFamily="Consolas" Margin="0,3,0,0" TextWrapping="Wrap"/>
    <TextBlock x:Name="Verdict" Text="右键设置" Foreground="#9AA0A6" FontSize="10"
               TextWrapping="Wrap" Margin="0,8,0,0"/>
  </StackPanel>
</Border>
'@

$rootEl = [System.Windows.Markup.XamlReader]::Parse($xaml)
$win.Content = $rootEl
foreach ($n in 'Title', 'Clock', 'Money', 'Sub', 'Burn', 'BurnSub', 'Verdict') {
  Set-Variable -Name "ui$n" -Value $rootEl.FindName($n) -Scope Script
}

# 拖动 / 双击
$win.Add_MouseLeftButtonDown({
  param($s, $e)
  if ($e.ClickCount -eq 2) { return }
  try { $s.DragMove() } catch { }
})
$win.Add_MouseRightButtonUp({ param($s, $e) Show-Menu })

# ---------------- 右键菜单 ----------------
function Show-Menu {
  $menu = New-Object System.Windows.Controls.ContextMenu

  $mi = New-Object System.Windows.Controls.MenuItem
  $mi.Header = if ($script:State.startedAt -gt 0) { '下班' } else { '开始上班' }
  $mi.Add_Click({
    if ($script:State.startedAt -gt 0) {
      $script:State.workedSec = Get-ElapsedSec
      $script:State.startedAt = 0
    } else {
      $script:State.startedAt = Get-EpochMs (Get-Date)
    }
    Save-Data; Update-Ui
  })
  [void]$menu.Items.Add($mi)

  $mi2 = New-Object System.Windows.Controls.MenuItem
  $mi2.Header = '设置…'
  $mi2.Add_Click({ Show-Settings })
  [void]$menu.Items.Add($mi2)

  $mi3 = New-Object System.Windows.Controls.MenuItem
  $mi3.Header = '始终置顶'
  $mi3.IsCheckable = $true
  $mi3.IsChecked = $win.Topmost
  $mi3.Add_Click({ $win.Topmost = $mi3.IsChecked })
  [void]$menu.Items.Add($mi3)

  [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))

  $mi4 = New-Object System.Windows.Controls.MenuItem
  $mi4.Header = '退出'
  $mi4.Add_Click({
    if ($script:State.startedAt -gt 0) {
      $script:State.workedSec = Get-ElapsedSec
      $script:State.startedAt = Get-EpochMs (Get-Date)
    }
    Save-Data
    $win.Close()
  })
  [void]$menu.Items.Add($mi4)

  $menu.PlacementTarget = $win
  $menu.IsOpen = $true
}

# ---------------- 设置窗 ----------------
function Show-Settings {
  $w = New-Object System.Windows.Window
  $w.Title = '追平 · 设置'
  $w.Width = 320; $w.Height = 330
  $w.WindowStartupLocation = 'CenterScreen'
  $w.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#1B1F23')
  $w.Topmost = $true

  $panel = New-Object System.Windows.Controls.StackPanel
  $panel.Margin = '18'

  function Add-Field($label, $value) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $label; $t.Foreground = '#9AA0A6'; $t.FontSize = 11; $t.Margin = '0,8,0,3'
    [void]$panel.Children.Add($t)
    $b = New-Object System.Windows.Controls.TextBox
    $b.Text = [string]$value; $b.FontFamily = 'Consolas'; $b.Padding = '6'
    [void]$panel.Children.Add($b)
    return $b
  }

  $salary = Add-Field '月薪（元）' $script:Cfg.monthlySalary
  $days = Add-Field '每月工作天数' $script:Cfg.workDays
  $hours = Add-Field '每天工时' $script:Cfg.hoursPerDay
  $price = Add-Field 'token 单价（元/百万）' $script:Cfg.tokenPrice
  $tokens = Add-Field '本月 token 总额' $script:State.tokens

  $ok = New-Object System.Windows.Controls.Button
  $ok.Content = '保存'; $ok.Margin = '0,14,0,0'; $ok.Padding = '8'
  $ok.Add_Click({
    function NumOr($txt, $fallback, $min) {
      $v = 0.0
      if ([double]::TryParse($txt.Text, [ref]$v)) { if ($v -lt $min) { return $min } else { return $v } }
      $fallback
    }
    $script:Cfg.monthlySalary = NumOr $salary $script:Cfg.monthlySalary 0
    $script:Cfg.workDays = NumOr $days $script:Cfg.workDays 1
    $script:Cfg.hoursPerDay = NumOr $hours $script:Cfg.hoursPerDay 1
    $script:Cfg.tokenPrice = NumOr $price $script:Cfg.tokenPrice 0
    $nt = NumOr $tokens $script:State.tokens 0
    if ($nt -ne $script:State.tokens -or $script:State.tokenAt -eq 0) {
      $script:State.tokens = $nt
      $script:State.tokenAt = Get-EpochMs (Get-Date)
    }
    $script:State.month = Get-MonthKey
    Save-Data; Update-Ui; $w.Close()
  })
  [void]$panel.Children.Add($ok)

  $w.Content = $panel
  $w.ShowDialog() | Out-Null
}

# ---------------- 刷新 ----------------
function Update-Ui {
  $now = Get-Date
  if ($script:State.day -ne (Get-DayKey)) {
    $script:State.day = Get-DayKey; $script:State.workedSec = 0; $script:State.startedAt = 0
  }
  if ($script:State.month -ne (Get-MonthKey)) {
    $script:State.month = Get-MonthKey; $script:State.tokens = 0; $script:State.tokenAt = Get-EpochMs $now
  }

  $secs = Get-ElapsedSec
  $rate = Get-SalaryPerSec
  $earned = $secs * $rate
  $hourly = $rate * 3600

  $uiClock.Text = $now.ToString('HH:mm:ss')
  $uiMoney.Text = '¥' + (Format-Money $earned)
  $state = if ($script:State.startedAt -gt 0) { '上班中' } else { '未开工' }
  $uiSub.Text = "$state · 工时 $([math]::Round($secs/3600,2))h · 时薪 ¥$(Format-Money $hourly)"

  $t = Get-TokenStats
  if ($null -eq $t) {
    $uiBurn.Text = '—'
    $uiBurnSub.Text = if ($script:State.tokens -le 0) { '未填写本月总额（右键设置）' } else { '本月数据不足一天' }
    $uiVerdict.Text = '填了 token 总额，就能算出赚的和烧的差多少'
  } else {
    $midnight = [datetime]::new($now.Year, $now.Month, $now.Day)
    $secsToday = ($now - $midnight).TotalSeconds
    $burnToday = $t.yuanPerSec * $secsToday
    $burnText = if ($burnToday -lt 0.01) { $burnToday.ToString('0.000000') } else { Format-Money $burnToday }
    $uiBurn.Text = '¥' + $burnText

    $perDayText = if ($t.perDay -ge 10000) { '{0:N0} 万' -f ($t.perDay / 10000) } else { '{0:N0}' -f $t.perDay }
    $uiBurnSub.Text = "日均 $perDayText · 每秒 $([math]::Round($t.perSec)) tokens · ¥$($t.yuanPerSec.ToString('0.000000'))/秒"

    $mult = if ($burnToday -gt 0) { $earned / $burnToday } else { 0 }
    $multText = if ($mult -ge 100) { '{0:N0}' -f $mult } else { '{0:N1}' -f $mult }
    $uiVerdict.Text = "赚的是烧的 $multText 倍 · 净入 ¥$(Format-Money ($earned - $burnToday))"
  }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
  Update-Ui
  if (((Get-Date) - $script:LastSave).TotalSeconds -gt 5) {
    $script:LastSave = Get-Date
    Save-Data
  }
})
$script:LastSave = Get-Date
$timer.Start()

$win.Add_Closed({ Save-Data; $timer.Stop() })

# 默认位置：屏幕右下角
$wa = [System.Windows.SystemParameters]::WorkArea
$win.Add_Loaded({
  $win.Left = $wa.Right - $win.ActualWidth - 28
  $win.Top = $wa.Bottom - $win.ActualHeight - 28
  Update-Ui
})

[void]$win.ShowDialog()
