Function Get-BitLockerRecoveryKeyId {
    <#
	.SYNOPSIS
		This returns the Bitlocker key protector id.

	.DESCRIPTION
        The key protectorID is retrived either according to the protector type, or simply all of them.

	.PARAMETER KeyProtectorType

    The key protector type can have one of the following values :
        *TPM
        *ExternalKey
        *NumericPassword
        *TPMAndPin
        *TPMAndStartUpdKey
        *TPMAndPinAndStartUpKey
        *PublicKey
        *PassPhrase
        *TpmCertificate
        *SID


    .EXAMPLE

        Get-BitLockerRecoveryKeyId
        Returns all the ID's available from all the different protectors.

    .EXAMPLE

        Get-BitLockerRecoveryKeyId -KeyProtectorType NumericPassword
        Returns the ID(s) of type NumericPassword


	.NOTES
		Version: 1.0
        Author: Stephane van Gulick
        Creation date:12.08.2014
        Last modification date: 12.08.2014

	.LINK
		www.powershellDistrict.com

	.LINK
		http://social.technet.microsoft.com/profile/st%C3%A9phane%20vg/

    .LINK
        #http://msdn.microsoft.com/en-us/library/windows/desktop/aa376441(v=vs.85).aspx

#>
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeLine = $false)]
        [ValidateSet("Alltypes", "TPM", "ExternalKey", "NumericPassword", "TPMAndPin", "TPMAndStartUpdKey", "TPMAndPinAndStartUpKey", "PublicKey", "PassPhrase", "TpmCertificate", "SID")]
        $KeyProtectorType
    )

    $BitLocker = Get-WmiObject -Namespace "Root\cimv2\Security\MicrosoftVolumeEncryption" -Class "Win32_EncryptableVolume"

    switch ($KeyProtectorType) {
        ("Alltypes") { $Value = "0" }
        ("TPM") { $Value = "1" }
        ("ExternalKey") { $Value = "2" }
        ("NumericPassword") { $Value = "3" }
        ("TPMAndPin") { $Value = "4" }
        ("TPMAndStartUpdKey") { $Value = "5" }
        ("TPMAndPinAndStartUpKey") { $Value = "6" }
        ("PublicKey") { $Value = "7" }
        ("PassPhrase") { $Value = "8" }
        ("TpmCertificate") { $Value = "9" }
        ("SID") { $Value = "10" }
        default { $Value = "0" }
    }

    $Ids = $BitLocker.GetKeyProtectors($Value).volumekeyprotectorID
    return $ids
}