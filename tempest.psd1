@{
    # ---- Module Metadata ----
    RootModule        = 'src/Public/InvokeTempest.ps1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b5f55c84-ef11-4b0e-94b4-13f5b2c6a9d7'
    Author            = 'Your Name'
    CompanyName       = 'Open Defense Labs'
    Copyright         = '(c) 2025 Your Name. MIT License'
    Description       = 'T.E.M.P.E.S.T. — Threat-surface Enumeration: Modules, Ports, Extensions, Schedules & Tasks. A read-only, modular Windows attack-surface enumerator.'

    # ---- Functions to Export ----
    FunctionsToExport = @('Invoke-Tempest')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # ---- Dependencies / Requirements ----
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    RequiredModules   = @()
    RequiredAssemblies = @()
    ScriptsToProcess  = @()

    # ---- Localization / Data ----
    FileList = @(
        'src/Public/InvokeTempest.ps1',
        'src/Private/Get_HostSummary.ps1',
        'src/Private/Get_LocalServices.ps1',
        'src/Private/Get_ListeningPorts.ps1',
        'src/Private/Get_Autostart.ps1',
        'src/Private/Get_FirewallRules.ps1',
        'src/Private/Get_ScheduledTasks.ps1',
        'src/Private/Get_Drivers.ps1',
        'src/Private/Get_BrowserExtensions.ps1',
        'src/Helpers/Export_ToJson.ps1',
        'src/Helpers/Export_ToCsv.ps1',
        'src/Helpers/Build_HtmlReport.ps1'
    )

    # ---- Private Data / Notes ----
    PrivateData = @{
        PSData = @{
            Tags        = @('security', 'enumeration', 'powershell', 'windows', 'tempest')
            LicenseUri  = 'https://opensource.org/licenses/MIT'
            ProjectUri  = 'https://github.com/<your-username>/tempest'
            IconUri     = 'https://raw.githubusercontent.com/<your-username>/tempest/main/docs/icon.png'
            ReleaseNotes = 'Initial T.E.M.P.E.S.T. alpha. Enumerates local host surfaces into JSON, CSV, and HTML.'
        }
    }
}
