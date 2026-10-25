@{
    # CI fails only on Error-severity findings; warnings are left to editor tooling.
    Severity     = @('Error')

    ExcludeRules = @(
        # Get-WLANProfile and Get-CredentialFromWindowsCredentialManager wrap a password
        # they have already read back from the OS as a SecureString. The plaintext exists
        # either way; the conversion is what makes the output safer, not less.
        'PSAvoidUsingConvertToSecureStringWithPlainText'
    )
}
