# ffmpeg has 190+ single-dash options (-i, -c, -vf, -af, -b:v, ...), many of them
# codec/filter-specific, and no `completion powershell` generator of its own.
# `-h full` would add hundreds more codec/format-specific options on top of that,
# so this uses `-h long` - a wide but readable set of the actually common global
# and per-stream options. Parses ffmpeg's own help rather than hand-transcribing
# it, so it always matches whatever version is installed; cached for the rest of
# the session so repeated Tab presses don't re-run ffmpeg -h.
$Global:__ffmpegFlagCache = $null

Register-ArgumentCompleter -Native -CommandName ffmpeg -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    if ($wordToComplete -notlike '-*') { return }

    if (-not $Global:__ffmpegFlagCache) {
        $helpText = ffmpeg -hide_banner -h long 2>$null | Out-String
        $Global:__ffmpegFlagCache = [regex]::Matches($helpText, '(?<=^|\s)(-[a-zA-Z_][\w_]*)') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    }

    $Global:__ffmpegFlagCache | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
    }
}
