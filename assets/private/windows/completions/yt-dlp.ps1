# yt-dlp has 270+ long-form flags across many option groups (General, Network,
# Video Selection, Download, Filesystem, Format, Subtitle, Authentication,
# Post-processing, SponsorBlock, Extractor, ...) and no `completion powershell`
# generator of its own. Hand-transcribing that list would go stale the moment
# yt-dlp adds or renames a flag, so instead this parses `yt-dlp --help` itself -
# always matches whatever version is actually installed - and caches the result
# for the rest of the session so repeated Tab presses don't re-run --help.
$Global:__ytdlpFlagCache = $null

Register-ArgumentCompleter -Native -CommandName yt-dlp -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    if ($wordToComplete -notlike '-*') { return }

    if (-not $Global:__ytdlpFlagCache) {
        $helpText = yt-dlp --help 2>$null | Out-String
        $Global:__ytdlpFlagCache = [regex]::Matches($helpText, '(?<=^|\s)(--[a-zA-Z][\w-]*)') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    }

    $Global:__ytdlpFlagCache | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
