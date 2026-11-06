@{
    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true
    ExcludeRules        = @('PSUseBOMForUnicodeEncodedFile')

    Rules               = @{
        PSPlaceOpenBrace                          = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }
        PSPlaceCloseBrace                         = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }
        PSUseConsistentIndentation                = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 0
        }
        PSUseConsistentWhitespace                 = @{
            Enable                                  = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckSeparator                          = $true
            CheckInnerBrace                         = $true
            CheckParameter                          = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSAlignAssignmentStatement                = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
        }
        PSAvoidSemicolonsAsLineTerminators        = @{
            Enable = $true
        }
        PSUseCorrectCasing                        = @{
            Enable = $true
        }
    }
}
