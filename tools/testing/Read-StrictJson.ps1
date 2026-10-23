Set-StrictMode -Version Latest

function ConvertFrom-Phase2RStrictJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json,
        [Parameter(Mandatory = $true)][string]$Label
    )

    function Skip-JsonWhitespace {
        param([string]$Text, [ref]$Position)
        while ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -in @(' ', "`t", "`r", "`n")) {
            $Position.Value += 1
        }
    }

    function Read-JsonString {
        param([string]$Text, [ref]$Position, [string]$Path)
        $start = $Position.Value
        if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne '"') {
            throw "JSON_STRING_EXPECTED: $Label at $Path byte=$($Position.Value)"
        }
        $Position.Value += 1
        while ($Position.Value -lt $Text.Length) {
            $character = $Text[$Position.Value]
            if ([int][char]$character -lt 0x20) { throw "JSON_CONTROL_CHARACTER: $Label at $Path byte=$($Position.Value)" }
            if ($character -ceq '"') {
                $Position.Value += 1
                $token = $Text.Substring($start, $Position.Value - $start)
                return ConvertFrom-Json -InputObject $token -ErrorAction Stop
            }
            if ($character -ceq '\') {
                $Position.Value += 1
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -notin @('"','\','/','b','f','n','r','t','u')) {
                    throw "JSON_ESCAPE_INVALID: $Label at $Path byte=$($Position.Value)"
                }
                if ($Text[$Position.Value] -ceq 'u') {
                    if ($Position.Value + 4 -ge $Text.Length -or $Text.Substring($Position.Value + 1, 4) -notmatch '^[0-9a-fA-F]{4}$') {
                        throw "JSON_UNICODE_ESCAPE_INVALID: $Label at $Path byte=$($Position.Value)"
                    }
                    $Position.Value += 4
                }
            }
            $Position.Value += 1
        }
        throw "JSON_UNTERMINATED_STRING: $Label at $Path byte=$($Position.Value)"
    }

    function Read-JsonValue {
        param([string]$Text, [ref]$Position, [string]$Path)
        Skip-JsonWhitespace $Text $Position
        if ($Position.Value -ge $Text.Length) { throw "JSON_UNEXPECTED_EOF: $Label at $Path" }
        $character = $Text[$Position.Value]
        if ($character -ceq '{') {
            $Position.Value += 1
            $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            Skip-JsonWhitespace $Text $Position
            if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq '}') { $Position.Value += 1; return }
            while ($true) {
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne '"') {
                    throw "JSON_OBJECT_KEY_EXPECTED: $Label at $Path byte=$($Position.Value)"
                }
                $key = [string](Read-JsonString $Text $Position $Path)
                if (-not $seen.Add($key)) { throw "JSON_DUPLICATE_MEMBER: $Label at $Path.$key" }
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ':') {
                    throw "JSON_COLON_EXPECTED: $Label at $Path.$key byte=$($Position.Value)"
                }
                $Position.Value += 1
                Read-JsonValue $Text $Position ($Path + '.' + $key)
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq '}') { $Position.Value += 1; return }
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ',') {
                    throw "JSON_COMMA_OR_OBJECT_END: $Label at $Path byte=$($Position.Value)"
                }
                $Position.Value += 1
            }
        }
        if ($character -ceq '[') {
            $Position.Value += 1
            Skip-JsonWhitespace $Text $Position
            if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq ']') { $Position.Value += 1; return }
            $index = 0
            while ($true) {
                Read-JsonValue $Text $Position ("$Path[$index]")
                $index += 1
                Skip-JsonWhitespace $Text $Position
                if ($Position.Value -lt $Text.Length -and $Text[$Position.Value] -ceq ']') { $Position.Value += 1; return }
                if ($Position.Value -ge $Text.Length -or $Text[$Position.Value] -cne ',') {
                    throw "JSON_COMMA_OR_ARRAY_END: $Label at $Path byte=$($Position.Value)"
                }
                $Position.Value += 1
            }
        }
        if ($character -ceq '"') { [void](Read-JsonString $Text $Position $Path); return }
        $remaining = $Text.Substring($Position.Value)
        $match = [regex]::Match($remaining, '^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)')
        if (-not $match.Success) { throw "JSON_VALUE_INVALID: $Label at $Path byte=$($Position.Value)" }
        $Position.Value += $match.Length
    }

    $position = 0
    $positionRef = [ref]$position
    Read-JsonValue $Json $positionRef '$'
    Skip-JsonWhitespace $Json $positionRef
    if ($position -ne $Json.Length) { throw "JSON_TRAILING_DATA: $Label byte=$position" }
    return ConvertFrom-Json -InputObject $Json -ErrorAction Stop
}
