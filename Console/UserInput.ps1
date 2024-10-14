Function Read-HostExample {
    <#
    .SYNOPSIS
    Read a line of input from the console with an example for the user
    
    .DESCRIPTION
    The `Read-HostExample` cmdlet reads a line of input from the console (stdin) and allows for an example,
    or 'ghost', to show user what you would like. You can also use it to prompt a user for input. Because
    you can save the input as a secure string, you can use this cmdlet to prompt users for secure data,
    such as passwords.

    > [!NOTE] > There is a limit of 1022 characters can be accepted as input from a user.

    .PARAMETER AsSecureString
    Indicates that the cmdlet displays asterisks (`*`) in place of the characters that the user types as
    input. When you use this parameter, the output of the `Read-HostExample` cmdlet is a SecureString
    object ( System.Security.SecureString )

    .PARAMETER MaskInput
    Indicates that the cmdlet displays asterisks (`*`) in place of the characters that the user types as
    input. When you use this parameter, the output of the `Read-HostExample` cmdlet is a String object.
    This allows you to safely prompt for a password that is returned as plaintext instead of SecureString.

    .PARAMETER Prompt
    Specifies the text of the prompt. Type a string. If the string includes spaces, enclose it in
    quotation marks. It will appends a colon (`:`) to the text that you enter.

    .PARAMETER Example
    Specifies the text of the example for user input. Type a string. If the string includes spaces,
    enclose it in quotation marks. The text will be overwriten by the user's input as they type and
    will be displayed in the ANSI color defined in `GhostColor`

    .PARAMETER GhostColor
    Indicates what ANSI color to use to display the `Example` value for the user's input. Type is a
    integer. It should be of the ANSI values to specify color. The default is dark gray (90).

    .INPUTS
    System.String for Prompt directly from the pipeline or as a property of an object via pipeline

    System.String for Example as a property of an object via a pipeline

    .OUTPUTS
    System.String or System.Security.SecureString
       If the AsSecureString parameter is used, `Read-HostExample` returns a SecureString . Otherwise,
       it returns a string.

    .NOTES
    This cmdlet only reads from the stdin stream of the host process. Usually, the stdin stream is
    connected to the keyboard of the host console.

    --------- Example 1: Save console input to a variable ---------

    $Age = Read-HostExample -Prompt "Please enter your age" -Example "(1-99)"

    ------- Example 2: Save console input as a secure string -------

    $pwd_secure_string = Read-HostExample "Enter a Password" -Example "P@ssw0rd" -AsSecureString

    ------- Example 3: Mask input and as a plaintext string -------

    $pwd_string = Read-HostExample "Enter a Password" "P@ssw0rd" -MaskInput

    .LINK
    Online Version: https://raw.githubusercontent.com/smallfoxx/Tools/refs/heads/master/Console/UserInput.ps1
    Read-Host
    Clear-Host
    Get-Host
    Write-Host
    ConvertFrom-SecureString

    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]$Prompt,
        [parameter(ValueFromPipelineByPropertyName=$true,Position=1)]
        [alias('Ghost','GhostPrompt')]
        [string]$Example,
        [parameter(ParameterSetName="Default")]
        [switch]$MaskInput,
        [parameter(ParameterSetName="Secure",Mandatory)]
        [switch]$AsSecureString,
        [parameter(Position=2)]
        [int]$GhostColor=90
    )

    Process {
        Write-Host "$($Prompt): " -NoNewline
        $PreExample=[PSCustomObject]@{
            #Save the position of where the cursor is at
            "Left" = [System.Console]::CursorLeft
            "Top"  = [System.Console]::CursorTop 
        }

        Write-Host "`e[$($GhostColor)m$($Example)`e[0m" -NoNewline

        #Jump the cursor back to the position before the example.
        [System.Console]::SetCursorPosition($PreExample.Left, $PreExample.Top)

        If ($AsSecureString) {
            Read-Host -AsSecureString
        } else {
            Read-Host -MaskInput:$MaskInput
        }
    }
}
