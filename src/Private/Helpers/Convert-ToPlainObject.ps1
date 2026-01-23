function Convert-ToPlainObject {
    param ($InputObject)

    $o = [ordered]@{}
    foreach ($p in $InputObject.PSObject.Properties) {
        if ($p.MemberType -in 'NoteProperty','Property') {
            try { $o[$p.Name] = $p.Value }
            catch { $o[$p.Name] = '[UNREADABLE]' }
        }
    }
    [pscustomobject]$o
}
