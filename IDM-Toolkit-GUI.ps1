<#
  IDM Toolkit - Native IDM-Style Graphical User Interface
  Version 3.6
#>

# Self-elevate to Administrator if not already elevated
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        exit 0
    }
    catch {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Administrator rights are required to manage IDM settings.`nPlease right-click the launcher and select 'Run as administrator'.",
            "IDM Toolkit - Elevation Required",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        exit 1
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$script:CurrentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$script:ToolkitScript = Join-Path $script:CurrentDir 'IDM-Toolkit.ps1'

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Internet Download Manager Toolkit" Height="670" Width="960"
    WindowStartupLocation="CenterScreen" Background="{DynamicResource WindowBg}"
    FontFamily="Segoe UI" FontSize="12">

    <Window.Resources>
        <!-- Dynamic Color Brushes (Default Classic Light) -->
        <SolidColorBrush x:Key="WindowBg" Color="#F0F2F5"/>
        <SolidColorBrush x:Key="MenuBg" Color="#F5F6F8"/>
        <SolidColorBrush x:Key="ToolbarBg" Color="#E9ECF0"/>
        <SolidColorBrush x:Key="BorderColor" Color="#C8CCD4"/>
        <SolidColorBrush x:Key="PanelBg" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="HeaderBg" Color="#DFE3E8"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#222222"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#444444"/>
        <SolidColorBrush x:Key="LogConsoleBg" Color="#1E1E1E"/>
        <SolidColorBrush x:Key="LogConsoleFg" Color="#81C784"/>
        <SolidColorBrush x:Key="GridHeaderBg" Color="#E4E7EB"/>

        <!-- IDM Toolbar Button Style -->
        <Style x:Key="IdmToolBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Margin" Value="2,1"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#E2EDF8"/>
                    <Setter Property="BorderBrush" Value="#A4C2E6"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#C9DFFA"/>
                    <Setter Property="BorderBrush" Value="#7FAAE0"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="{DynamicResource GridHeaderBg}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderColor}"/>
        </Style>

        <Style TargetType="ListViewItem">
            <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
            <Setter Property="Margin" Value="0,1"/>
        </Style>

        <Style TargetType="TreeViewItem">
            <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Menu Bar -->
        <Menu Grid.Row="0" Background="{DynamicResource MenuBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="0,0,0,1" Padding="4,2">
            <MenuItem Header="_Tasks" Foreground="{DynamicResource TextPrimary}">
                <MenuItem Header="_Activate License" x:Name="MenuActivate"/>
                <MenuItem Header="_Freeze Trial Period" x:Name="MenuFreeze"/>
                <MenuItem Header="_Wipe and Reset All" x:Name="MenuReset"/>
                <Separator/>
                <MenuItem Header="E_xit" x:Name="MenuExit"/>
            </MenuItem>
            <MenuItem Header="_Maintenance" Foreground="{DynamicResource TextPrimary}">
                <MenuItem Header="_Backup Settings (JSON)" x:Name="MenuBackup"/>
                <MenuItem Header="_Restore Settings (JSON)" x:Name="MenuRestore"/>
                <Separator/>
                <MenuItem Header="_View Diagnostic Log" x:Name="MenuViewLog"/>
            </MenuItem>
            <MenuItem Header="_View" Foreground="{DynamicResource TextPrimary}">
                <MenuItem Header="_Classic Light Theme (IDM)" x:Name="MenuThemeLight"/>
                <MenuItem Header="_Modern Slate Dark Theme" x:Name="MenuThemeDark"/>
            </MenuItem>
            <MenuItem Header="_IDM" Foreground="{DynamicResource TextPrimary}">
                <MenuItem Header="_Launch Internet Download Manager" x:Name="MenuLaunchIdm"/>
                <MenuItem Header="_Download Official Installer" x:Name="MenuInstaller"/>
            </MenuItem>
            <MenuItem Header="_Help" Foreground="{DynamicResource TextPrimary}">
                <MenuItem Header="_Documentation and Guides" x:Name="MenuHelp"/>
                <MenuItem Header="_About IDM Toolkit" x:Name="MenuAbout"/>
            </MenuItem>
        </Menu>

        <!-- IDM Top Toolbar -->
        <Border Grid.Row="1" Background="{DynamicResource ToolbarBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="0,0,0,1" Padding="6,3">
            <StackPanel Orientation="Horizontal">
                <!-- Activate -->
                <Button x:Name="BtnActivate" Style="{StaticResource IdmToolBtn}" ToolTip="Activate IDM with perpetual registration">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#2E7D32" Margin="0,0,0,2"
                              Data="M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"/>
                        <TextBlock Text="Activate" FontWeight="SemiBold" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <!-- Freeze -->
                <Button x:Name="BtnFreeze" Style="{StaticResource IdmToolBtn}" ToolTip="Freeze trial counter for unlimited evaluation">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#0277BD" Margin="0,0,0,2"
                              Data="M12 2c5.52 0 10 4.48 10 10s-4.48 10-10 10S2 17.52 2 12 6.48 2 12 2zm0 18c4.42 0 8-3.58 8-8s-3.58-8-8-8-8 3.58-8 8 3.58 8 8 8zm1-13h-2v6l5.25 3.15.75-1.23-4.5-2.67V7z"/>
                        <TextBlock Text="Freeze Trial" FontWeight="SemiBold" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <!-- Reset -->
                <Button x:Name="BtnReset" Style="{StaticResource IdmToolBtn}" ToolTip="Completely wipe all IDM registration data and trial locks">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#C62828" Margin="0,0,0,2"
                              Data="M16 9v10H8V9h8m-1.5-6h-5l-1 1H5v2h14V4h-3.5l-1-1zM18 7H6v12c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7z"/>
                        <TextBlock Text="Reset IDM" FontWeight="SemiBold" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <Separator Style="{x:Null}" Margin="6,3" Width="1" Background="{DynamicResource BorderColor}"/>

                <!-- Backup -->
                <Button x:Name="BtnBackup" Style="{StaticResource IdmToolBtn}" ToolTip="Export IDM configuration and categories to JSON">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#6A1B9A" Margin="0,0,0,2"
                              Data="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"/>
                        <TextBlock Text="Backup" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <!-- Restore -->
                <Button x:Name="BtnRestore" Style="{StaticResource IdmToolBtn}" ToolTip="Restore IDM configuration from JSON backup">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#EF6C00" Margin="0,0,0,2"
                              Data="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm0 12H4V8h16v10z"/>
                        <TextBlock Text="Restore" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <Separator Style="{x:Null}" Margin="6,3" Width="1" Background="{DynamicResource BorderColor}"/>

                <!-- Theme Toggle -->
                <Button x:Name="BtnToggleTheme" Style="{StaticResource IdmToolBtn}" ToolTip="Switch between Light and Dark visual themes">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#7B1FA2" Margin="0,0,0,2"
                              Data="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"/>
                        <TextBlock Text="Theme" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <Separator Style="{x:Null}" Margin="6,3" Width="1" Background="{DynamicResource BorderColor}"/>

                <!-- Launch IDM -->
                <Button x:Name="BtnLaunchIdm" Style="{StaticResource IdmToolBtn}" ToolTip="Start Internet Download Manager">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#1565C0" Margin="0,0,0,2"
                              Data="M8 5v14l11-7z"/>
                        <TextBlock Text="Start IDM" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <!-- Installer -->
                <Button x:Name="BtnInstaller" Style="{StaticResource IdmToolBtn}" ToolTip="Download latest official IDM installer">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#37474F" Margin="0,0,0,2"
                              Data="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/>
                        <TextBlock Text="Get IDM" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>

                <!-- Help -->
                <Button x:Name="BtnHelp" Style="{StaticResource IdmToolBtn}" ToolTip="View guides and troubleshooting">
                    <StackPanel HorizontalAlignment="Center">
                        <Path Width="24" Height="24" Stretch="Uniform" Fill="#00838F" Margin="0,0,0,2"
                              Data="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 16h-2v-2h2v2zm1.07-7.75l-.9.92C12.45 11.9 12 12.5 12 14h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H7c0-2.76 2.24-5 5-5s5 2.24 5 5c0 1.04-.42 1.99-1.07 2.67z"/>
                        <TextBlock Text="Help" FontSize="11" HorizontalAlignment="Center" Foreground="{DynamicResource TextPrimary}"/>
                    </StackPanel>
                </Button>
            </StackPanel>
        </Border>

        <!-- Main Body: Categories Left + IDM Grid Right -->
        <Grid Grid.Row="2" Margin="6">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="200" MinWidth="160"/>
                <ColumnDefinition Width="4"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Left Panel: Categories -->
            <Border Grid.Column="0" Background="{DynamicResource PanelBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="1" CornerRadius="2">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="{DynamicResource HeaderBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="0,0,0,1" Padding="8,5">
                        <TextBlock Text="Categories" FontWeight="Bold" Foreground="{DynamicResource TextPrimary}" FontSize="11"/>
                    </Border>
                    <TreeView Grid.Row="1" BorderThickness="0" Background="Transparent" Padding="4">
                        <TreeViewItem Header="All Tasks" IsExpanded="True" FontWeight="SemiBold">
                            <TreeViewItem Header="Activate License" x:Name="TreeActivate" FontWeight="Normal" Cursor="Hand"/>
                            <TreeViewItem Header="Freeze Trial" x:Name="TreeFreeze" FontWeight="Normal" Cursor="Hand"/>
                            <TreeViewItem Header="Wipe and Reset" x:Name="TreeReset" FontWeight="Normal" Cursor="Hand"/>
                        </TreeViewItem>
                        <TreeViewItem Header="Maintenance" IsExpanded="True" FontWeight="SemiBold">
                            <TreeViewItem Header="Backup Settings" x:Name="TreeBackup" FontWeight="Normal" Cursor="Hand"/>
                            <TreeViewItem Header="Restore Settings" x:Name="TreeRestore" FontWeight="Normal" Cursor="Hand"/>
                        </TreeViewItem>
                        <TreeViewItem Header="Information" IsExpanded="True" FontWeight="SemiBold">
                            <TreeViewItem Header="System Environment" x:Name="TreeEnv" FontWeight="Normal" Cursor="Hand"/>
                            <TreeViewItem Header="Check Network" x:Name="TreeNet" FontWeight="Normal" Cursor="Hand"/>
                        </TreeViewItem>
                    </TreeView>
                </Grid>
            </Border>

            <!-- Splitter -->
            <GridSplitter Grid.Column="1" Width="4" HorizontalAlignment="Stretch" Background="Transparent"/>

            <!-- Right Panel: IDM ListView + Log Console -->
            <Grid Grid.Column="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="200" MinHeight="130"/>
                    <RowDefinition Height="4"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <!-- IDM Style Task / Status Grid -->
                <Border Grid.Row="0" Background="{DynamicResource PanelBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="1" CornerRadius="2">
                    <ListView x:Name="LstStatusGrid" BorderThickness="0" Background="Transparent">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Component" Width="140" DisplayMemberBinding="{Binding Component}"/>
                                <GridViewColumn Header="Status" Width="130" DisplayMemberBinding="{Binding Status}"/>
                                <GridViewColumn Header="Value / Details" Width="180" DisplayMemberBinding="{Binding Details}"/>
                                <GridViewColumn Header="Path / Target" Width="260" DisplayMemberBinding="{Binding Path}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Border>

                <!-- Splitter -->
                <GridSplitter Grid.Row="1" Height="4" HorizontalAlignment="Stretch" Background="Transparent"/>

                <!-- Bottom Log Console -->
                <Border Grid.Row="2" Background="{DynamicResource PanelBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="1" CornerRadius="2">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <Border Grid.Row="0" Background="{DynamicResource HeaderBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="0,0,0,1" Padding="8,4">
                            <DockPanel>
                                <TextBlock Text="Activity and Execution Log" FontWeight="Bold" Foreground="{DynamicResource TextPrimary}" FontSize="11" VerticalAlignment="Center"/>
                                <Button x:Name="BtnClearLog" Content="Clear Log" HorizontalAlignment="Right" Padding="8,2" FontSize="11"/>
                            </DockPanel>
                        </Border>
                        <TextBox x:Name="TxtLogConsole" Grid.Row="1" Background="{DynamicResource LogConsoleBg}" Foreground="{DynamicResource LogConsoleFg}"
                                 FontFamily="Consolas" FontSize="11.5" IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                                 HorizontalScrollBarVisibility="Auto" TextWrapping="Wrap" Padding="8" BorderThickness="0"/>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- Status Bar -->
        <StatusBar Grid.Row="3" Background="{DynamicResource HeaderBg}" BorderBrush="{DynamicResource BorderColor}" BorderThickness="0,1,0,0" Padding="4,2">
            <StatusBarItem>
                <TextBlock x:Name="TxtFooterStatus" Text="Status: Ready" FontWeight="SemiBold" Foreground="{DynamicResource TextPrimary}"/>
            </StatusBarItem>
            <Separator Width="1" Background="{DynamicResource BorderColor}"/>
            <StatusBarItem>
                <TextBlock x:Name="TxtFooterIdm" Text="IDM: Checking..." Foreground="{DynamicResource TextSecondary}"/>
            </StatusBarItem>
            <Separator Width="1" Background="{DynamicResource BorderColor}"/>
            <StatusBarItem>
                <TextBlock x:Name="TxtFooterOs" Text="System: Checking..." Foreground="{DynamicResource TextSecondary}"/>
            </StatusBarItem>
            <Separator Width="1" Background="{DynamicResource BorderColor}"/>
            <StatusBarItem HorizontalAlignment="Right">
                <TextBlock x:Name="TxtFooterNet" Text="Server: Checking..." Foreground="{DynamicResource TextSecondary}"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Element References
$LstStatusGrid   = $window.FindName('LstStatusGrid')
$TxtLogConsole   = $window.FindName('TxtLogConsole')
$TxtFooterStatus = $window.FindName('TxtFooterStatus')
$TxtFooterIdm    = $window.FindName('TxtFooterIdm')
$TxtFooterOs     = $window.FindName('TxtFooterOs')
$TxtFooterNet    = $window.FindName('TxtFooterNet')

$BtnActivate    = $window.FindName('BtnActivate')
$BtnFreeze      = $window.FindName('BtnFreeze')
$BtnReset       = $window.FindName('BtnReset')
$BtnBackup      = $window.FindName('BtnBackup')
$BtnRestore     = $window.FindName('BtnRestore')
$BtnToggleTheme = $window.FindName('BtnToggleTheme')
$BtnLaunchIdm   = $window.FindName('BtnLaunchIdm')
$BtnInstaller   = $window.FindName('BtnInstaller')
$BtnHelp        = $window.FindName('BtnHelp')
$BtnClearLog    = $window.FindName('BtnClearLog')

# Menu Items
$MenuActivate   = $window.FindName('MenuActivate')
$MenuFreeze     = $window.FindName('MenuFreeze')
$MenuReset      = $window.FindName('MenuReset')
$MenuBackup     = $window.FindName('MenuBackup')
$MenuRestore    = $window.FindName('MenuRestore')
$MenuViewLog    = $window.FindName('MenuViewLog')
$MenuThemeLight = $window.FindName('MenuThemeLight')
$MenuThemeDark  = $window.FindName('MenuThemeDark')
$MenuLaunchIdm  = $window.FindName('MenuLaunchIdm')
$MenuInstaller  = $window.FindName('MenuInstaller')
$MenuHelp       = $window.FindName('MenuHelp')
$MenuAbout      = $window.FindName('MenuAbout')
$MenuExit       = $window.FindName('MenuExit')

# Tree Items
$TreeActivate  = $window.FindName('TreeActivate')
$TreeFreeze    = $window.FindName('TreeFreeze')
$TreeReset     = $window.FindName('TreeReset')
$TreeBackup    = $window.FindName('TreeBackup')
$TreeRestore   = $window.FindName('TreeRestore')
$TreeEnv       = $window.FindName('TreeEnv')
$TreeNet       = $window.FindName('TreeNet')

# ─────────────────────────────────────────────────────────────
#  Theme Switcher Engine
# ─────────────────────────────────────────────────────────────

function New-Brush([string]$HexColor) {
    $col = [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
    return [System.Windows.Media.SolidColorBrush]::new($col)
}

$script:CurrentTheme = 'Light'

function Set-WpfTheme([string]$ThemeName) {
    if ($ThemeName -eq 'Dark') {
        $window.Resources['WindowBg']        = New-Brush '#12111D'
        $window.Resources['MenuBg']          = New-Brush '#181628'
        $window.Resources['ToolbarBg']       = New-Brush '#1E1B2E'
        $window.Resources['BorderColor']     = New-Brush '#2D2845'
        $window.Resources['PanelBg']         = New-Brush '#181628'
        $window.Resources['HeaderBg']        = New-Brush '#2A2640'
        $window.Resources['TextPrimary']     = New-Brush '#F0F0FF'
        $window.Resources['TextSecondary']   = New-Brush '#A0A0B0'
        $window.Resources['LogConsoleBg']    = New-Brush '#0A0912'
        $window.Resources['LogConsoleFg']    = New-Brush '#00FF66'
        $window.Resources['GridHeaderBg']    = New-Brush '#2A2640'
        $script:CurrentTheme = 'Dark'
        Write-GuiLog "Switched UI visual theme to Modern Slate Dark." 'THEME'
    } else {
        $window.Resources['WindowBg']        = New-Brush '#F0F2F5'
        $window.Resources['MenuBg']          = New-Brush '#F5F6F8'
        $window.Resources['ToolbarBg']       = New-Brush '#E9ECF0'
        $window.Resources['BorderColor']     = New-Brush '#C8CCD4'
        $window.Resources['PanelBg']         = New-Brush '#FFFFFF'
        $window.Resources['HeaderBg']        = New-Brush '#DFE3E8'
        $window.Resources['TextPrimary']     = New-Brush '#222222'
        $window.Resources['TextSecondary']   = New-Brush '#444444'
        $window.Resources['LogConsoleBg']    = New-Brush '#1E1E1E'
        $window.Resources['LogConsoleFg']    = New-Brush '#81C784'
        $window.Resources['GridHeaderBg']    = New-Brush '#E4E7EB'
        $script:CurrentTheme = 'Light'
        Write-GuiLog "Switched UI visual theme to Classic Light (IDM)." 'THEME'
    }

    # Save preference
    try {
        @{ Theme = $script:CurrentTheme } | ConvertTo-Json | Set-Content (Join-Path $script:CurrentDir 'theme.json') -Force
    } catch {}
}

# ─────────────────────────────────────────────────────────────
#  Logging and UI Updates
# ─────────────────────────────────────────────────────────────

function Write-GuiLog([string]$Message, [string]$Type = 'INFO') {
    $ts = (Get-Date).ToString('HH:mm:ss')
    $line = "[$ts] [$Type] $Message`r`n"
    $window.Dispatcher.Invoke([Action]{
        $TxtLogConsole.AppendText($line)
        $TxtLogConsole.ScrollToEnd()
    })
}

function Set-Footer([string]$Text) {
    $window.Dispatcher.Invoke([Action]{
        $TxtFooterStatus.Text = "Status: $Text"
    })
}

function Update-EnvironmentCards {
    Write-GuiLog "Probing IDM and Windows system state..." 'INFO'
    try {
        $build = [Environment]::OSVersion.Version.Build
        $osRaw = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA SilentlyContinue).ProductName
        $os    = if ($build -ge 22000 -and $osRaw -match 'Windows 10') { $osRaw -replace 'Windows 10', 'Windows 11' } else { $osRaw }
        $archRaw = $env:PROCESSOR_ARCHITECTURE
        $arch    = if ($archRaw -eq 'AMD64' -or $archRaw -eq 'IA64') { 'x64' } else { $archRaw }
        $dmKey = 'HKCU:\Software\DownloadManager'
        $idmExe = "$env:ProgramFiles\Internet Download Manager\IDMan.exe"
        if (-not (Test-Path $idmExe)) {
            $idmExe = "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe"
        }

        $idmInstalled = Test-Path $idmExe
        $rawVers = $null
        if (Test-Path $dmKey) {
            $rawVers = (Get-ItemProperty $dmKey -EA SilentlyContinue).idmvers
        }

        $cleanVers = if ($rawVers) { $rawVers.TrimStart('v','V') } else { 'Unknown' }
        $idmStatusText = if ($idmInstalled) { "Installed (v$cleanVers)" } else { "Not Detected" }

        $isOnline = Test-Connection -ComputerName 'internetdownloadmanager.com' -Count 1 -Quiet -EA SilentlyContinue
        $netText = if ($isOnline) { "Connected" } else { "Offline / Blocked" }

        $recentBackup = Get-ChildItem -Path $script:CurrentDir -Filter 'IDM_Backup_*.json' -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $backupText = if ($recentBackup) { $recentBackup.Name } else { "No backup file found" }

        $gridItems = @(
            [PSCustomObject]@{
                Component = "IDM Application"
                Status    = if ($idmInstalled) { "Ready" } else { "Missing" }
                Details   = if ($idmInstalled) { "Version $cleanVers" } else { "Not Installed" }
                Path      = if ($idmInstalled) { $idmExe } else { "https://www.internetdownloadmanager.com" }
            },
            [PSCustomObject]@{
                Component = "Trial & Registration"
                Status    = "Active"
                Details   = "Registry CLSID Protected"
                Path      = "HKCU:\Software\Classes\CLSID"
            },
            [PSCustomObject]@{
                Component = "Operating System"
                Status    = "Running"
                Details   = "$os ($arch)"
                Path      = "HKLM:\SOFTWARE\Microsoft\Windows NT"
            },
            [PSCustomObject]@{
                Component = "Current User"
                Status    = "Elevated Admin"
                Details   = "$env:USERNAME ($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))"
                Path      = "HKCU:\Software\DownloadManager"
            },
            [PSCustomObject]@{
                Component = "Server Reachability"
                Status    = $netText
                Details   = if ($isOnline) { "HTTP Reachable" } else { "Connection Failed" }
                Path      = "https://www.internetdownloadmanager.com"
            },
            [PSCustomObject]@{
                Component = "Recent Backup"
                Status    = if ($recentBackup) { "Available" } else { "None" }
                Details   = $backupText
                Path      = if ($recentBackup) { $recentBackup.FullName } else { $script:CurrentDir }
            }
        )

        $window.Dispatcher.Invoke([Action]{
            $LstStatusGrid.ItemsSource = $gridItems
            $TxtFooterIdm.Text = "IDM: $idmStatusText"
            $TxtFooterOs.Text  = "System: $arch | $os"
            $TxtFooterNet.Text = "Server: $netText"
        })
        Write-GuiLog "Probe complete. IDM=$idmStatusText, OS=$os ($arch), Net=$netText" 'SUCCESS'
    } catch {
        Write-GuiLog "Probe exception: $($_.Exception.Message)" 'WARN'
    }
}

function Run-ToolkitMode([string]$ModeName) {
    Set-Footer "Running $ModeName..."
    Write-GuiLog "Starting operation: $ModeName..." 'START'

    # Disable buttons during operation
    $BtnActivate.IsEnabled = $false
    $BtnFreeze.IsEnabled   = $false
    $BtnReset.IsEnabled    = $false
    $BtnBackup.IsEnabled   = $false
    $BtnRestore.IsEnabled  = $false

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:ToolkitScript`" -Mode $ModeName"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)

        while (-not $proc.HasExited) {
            while (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                if ($line) {
                    $clean = $line -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
                    if ($clean.Trim()) { Write-GuiLog $clean 'OUT' }
                }
            }
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
            Start-Sleep -Milliseconds 50
        }

        $rest = $proc.StandardOutput.ReadToEnd()
        if ($rest) {
            $clean = $rest -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
            foreach ($l in ($clean -split "`r?`n")) {
                if ($l.Trim()) { Write-GuiLog $l 'OUT' }
            }
        }

        $errs = $proc.StandardError.ReadToEnd()
        if ($errs) {
            Write-GuiLog $errs 'ERROR'
        }

        Set-Footer "Ready"
        Write-GuiLog "Operation $ModeName completed (ExitCode $($proc.ExitCode))." 'DONE'
    }
    catch {
        Write-GuiLog "Exception executing ${ModeName}: $($_.Exception.Message)" 'ERROR'
        Set-Footer "Error"
    }
    finally {
        $BtnActivate.IsEnabled = $true
        $BtnFreeze.IsEnabled   = $true
        $BtnReset.IsEnabled    = $true
        $BtnBackup.IsEnabled   = $true
        $BtnRestore.IsEnabled  = $true
        Update-EnvironmentCards
    }
}

# Actions Trigger Helpers
$actActivate = { Run-ToolkitMode 'license' }
$actFreeze   = { Run-ToolkitMode 'trial' }
$actReset    = {
    $res = [System.Windows.MessageBox]::Show(
        "Are you sure you want to completely wipe all IDM user registration and trial locks?`n`nThis resets IDM back to a clean 30-day trial.",
        "Confirm IDM Reset",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        Run-ToolkitMode 'wipe'
    }
}
$actBackup   = { Run-ToolkitMode 'backup' }
$actRestore  = { Run-ToolkitMode 'restore' }
$actLaunchIdm = {
    $dmExe = "$env:ProgramFiles\Internet Download Manager\IDMan.exe"
    if (-not (Test-Path $dmExe)) {
        $dmExe = "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe"
    }
    if (Test-Path $dmExe) {
        Start-Process $dmExe
        Write-GuiLog "Started Internet Download Manager ($dmExe)" 'INFO'
    } else {
        [System.Windows.MessageBox]::Show("IDM executable not found at $dmExe", "IDM Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
}
$actInstaller = { Start-Process 'https://www.internetdownloadmanager.com/download.html' }
$actHelp      = { Start-Process 'https://github.com/AvenalJ/IDM-Activator#readme' }

# Bind Buttons
$BtnActivate.Add_Click($actActivate)
$BtnFreeze.Add_Click($actFreeze)
$BtnReset.Add_Click($actReset)
$BtnBackup.Add_Click($actBackup)
$BtnRestore.Add_Click($actRestore)
$BtnToggleTheme.Add_Click({
    $nextTheme = if ($script:CurrentTheme -eq 'Light') { 'Dark' } else { 'Light' }
    Set-WpfTheme $nextTheme
})
$BtnLaunchIdm.Add_Click($actLaunchIdm)
$BtnInstaller.Add_Click($actInstaller)
$BtnHelp.Add_Click($actHelp)
$BtnClearLog.Add_Click({ $TxtLogConsole.Clear() })

# Bind Menu
$MenuActivate.Add_Click($actActivate)
$MenuFreeze.Add_Click($actFreeze)
$MenuReset.Add_Click($actReset)
$MenuBackup.Add_Click($actBackup)
$MenuRestore.Add_Click($actRestore)
$MenuViewLog.Add_Click({
    $logFile = Join-Path $script:CurrentDir 'IDM-Toolkit.log'
    if (Test-Path $logFile) { Start-Process notepad.exe $logFile }
})
$MenuThemeLight.Add_Click({ Set-WpfTheme 'Light' })
$MenuThemeDark.Add_Click({ Set-WpfTheme 'Dark' })
$MenuLaunchIdm.Add_Click($actLaunchIdm)
$MenuInstaller.Add_Click($actInstaller)
$MenuHelp.Add_Click($actHelp)
$MenuAbout.Add_Click({
    [System.Windows.MessageBox]::Show("IDM Toolkit v3.6`nInternet Download Manager Management Utility`nPowerShell Edition with Dynamic Theme Engine", "About IDM Toolkit", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
})
$MenuExit.Add_Click({ $window.Close() })

# Bind Tree Items
$TreeActivate.Add_Selected($actActivate)
$TreeFreeze.Add_Selected($actFreeze)
$TreeReset.Add_Selected($actReset)
$TreeBackup.Add_Selected($actBackup)
$TreeRestore.Add_Selected($actRestore)
$TreeEnv.Add_Selected({ Update-EnvironmentCards })
$TreeNet.Add_Selected({
    Write-GuiLog "Testing network reachability to IDM servers..." 'INFO'
    Update-EnvironmentCards
})

# Load Saved Theme
$window.Add_Loaded({
    $savedThemeFile = Join-Path $script:CurrentDir 'theme.json'
    if (Test-Path $savedThemeFile) {
        try {
            $savedData = Get-Content $savedThemeFile -Raw | ConvertFrom-Json
            if ($savedData.Theme) { Set-WpfTheme $savedData.Theme }
        } catch {}
    }
    Write-GuiLog "IDM Toolkit v3.6 Graphical Interface initialized." 'INFO'
    Update-EnvironmentCards
})

[void]$window.ShowDialog()
