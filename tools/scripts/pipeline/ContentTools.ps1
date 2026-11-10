# Pure text helpers for forms and views (no environment is called). Dot-sourced by Update-Forms.ps1 and Update-Views.ps1, and testable on saved XML.

# Replaces every <Role Id="{guid}" /> in a form XML: the production role id is translated to the id of the role with the same NAME in the target environment.
# A role that does not exist in the target is removed from the XML and reported in $Missing.
# $ProdRoleNames : hashtable lower-case production role id -> role name.   $TargetRoleIds : hashtable role name -> target role id.
function Convert-FormRoleIds([string]$Xml, [hashtable]$ProdRoleNames, [hashtable]$TargetRoleIds, [System.Collections.Generic.List[string]]$Missing) {
    $eval = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $id = $m.Groups[1].Value.ToLower()
        if (-not $ProdRoleNames.ContainsKey($id)) { $Missing.Add("unknown production role id $id"); return '' }
        $name = $ProdRoleNames[$id]
        if (-not $TargetRoleIds.ContainsKey($name)) { $Missing.Add("role '$name' does not exist in the target"); return '' }
        return '<Role Id="{' + $TargetRoleIds[$name] + '}" />'
    }
    return [regex]::Replace($Xml, '<Role Id="\{?([0-9a-fA-F-]{36})\}?"\s*/>', $eval)
}

# Puts the table object type code of the CURRENT (target) layout into the production layout XML: the code differs between environments.
function Convert-ViewObjectCode([string]$ProdLayoutXml, [string]$CurrentLayoutXml) {
    $m = [regex]::Match($CurrentLayoutXml, 'object="(\d+)"')
    if (-not $m.Success) { return $ProdLayoutXml }
    return [regex]::Replace($ProdLayoutXml, 'object="\d+"', 'object="' + $m.Groups[1].Value + '"')
}
