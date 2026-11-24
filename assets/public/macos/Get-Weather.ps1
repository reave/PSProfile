function Get-Weather {
    <#
    .SYNOPSIS
        Get the current weather conditions for a given city, zipcode, or geolocated zipcode
    .DESCRIPTION
        Gets the current weather coniditions for a given city, zipcode, or geolocated zipcode, and country combination.
        Values can be returned in Metric, or Imperial values. Geolocation uses your public IP's location.
    .PARAMETER Path
        Specifies a path to one or more locations.
    .PARAMETER LiteralPath
        Specifies a path to one or more locations. Unlike Path, the value of LiteralPath is used exactly as it
        is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose
        it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        characters as escape sequences.
    .PARAMETER City
        Specify the City you would like to get weather information for

        Note: cities that share names will return the best approximation for which one you mean based on the openweathermap api
    .PARAMETER ZipCode
        Specify the zipcode of the city you would like to get weather information for
    .PARAMETER Country
        Specify the country the city is in or the country the zipcode is in
    .PARAMETER Unit
        A validated list that contains:
        Metric,
        Imperial,
        Standard

        These will determine what the units of measurement we return data in
    .PARAMETER APIKey
        An open weathermap api key is required. Pass one using this parameter.
    .EXAMPLE
        C:\PS>.\Get-Weather.ps1 -City 'New York' -Country 'US' -Unit 'Imperial'

        Will report current weather for New York, US using Imperial Measurements
    .EXAMPLE
        C:\PS>.\Get-Weather.ps1 -ZipCode 10001 -Country 'US' -Unit 'Imperial' -APIKey 'your-api-key'

        Will report current weather for 10001, US using imperial measurements and the specified APIKey
    .EXAMPLE
        C:\PS>.\Get-Weather.ps1

        Will determine your zip code and country from your external IP's geolocation and then report current weather for that location.
    .LINK
        http://openweathermap.org/api
        http://openweathermap.org/current#other
        http://openweathermap.org/weather-data
        http://myip.dnsomatic.com
        http://freegeoip.net

        Invoke-WebRequest
        New-Object
        Write-Output
        Write-Error
        Write-Warning
        Write-Information

    .OUTPUTS
        An object containing the following values:
            City
            Country
            Latitude
            Longitude
            SunRise
            SunSet
            CurrentWeather
            NowTemperature
            HighTemperature
            LowTemperature
            Humidity
            Clouds
            Rain
            Wind
            WindSpeed
            WindDirection
            Pressure
    .NOTES
        Author: reave (https://github.com/reave)
        Creation Date: 06/01/2016
        Last Modified  Date: 06/07/2016
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$City = $Null,
        [Parameter(Mandatory = $false)]
        [string]$ZipCode = $Null,
        [Parameter(Mandatory = $false)]
        [string]$Country = "US",
        [Parameter(Mandatory = $false)]
        [ValidateSet('Metric', 'Imperial', 'Standard')]
        [string]$Unit = 'Imperial',
        [Parameter(Mandatory = $false)]
        [string]$APIKey = ""
    )

    begin {
        switch ($Unit) {
            'Metric' {
                $u = 'metric'
            }
            'Imperial' {
                $u = 'imperial'
            }
            'Standard' {
                $u = 'standard'
            }
        }

        if ($ZipCode -eq '' -and $City -ne '') {
            $APIPath = "http://api.openweathermap.org/data/2.5/weather?q=$City,$Country&APPID=$APIKey&units=$u&mode=xml"
        } elseif ($City -eq '' -and $ZipCode -ne '') {
            $APIPath = "http://api.openweathermap.org/data/2.5/weather?zip=$ZipCode,$Country&APPID=$APIKey&units=$u&mode=xml"
        } else {
            try {
                $MyPublicIP = (Invoke-WebRequest 'http://myip.dnsomatic.com' -UseBasicParsing).Content
                $html = Invoke-WebRequest -Uri "http://freegeoip.net/xml/$myPublicIP" -UseBasicParsing
                $content = [xml]$html.Content
                $ZipCode = $content.response.ZipCode
                $Country = $content.response.CountryCode

                if ($ZipCode -ne '' -and $Country -ne '') {
                    $APIPath = "http://api.openweathermap.org/data/2.5/weather?zip=$ZipCode,$Country&APPID=$APIKey&units=$u&mode=xml"
                } else {
                    $Properties = @{City = $Null
                        Country          = $Null
                        Latitude         = $Null
                        Longitude        = $Null
                        SunRise          = $Null
                        SunSet           = $Null
                        CurrentWeather   = $Null
                        NowTemperature   = $Null
                        HighTemperature  = $Null
                        LowTemperature   = $Null
                        Humidity         = $Null
                        Clouds           = $Null
                        Rain             = $Null
                        Wind             = $Null
                        WindSpeed        = $Null
                        WindDirection    = $Null
                        Pressure         = $Null
                    }
                    $obj = New-Object -TypeName psobject -Property $properties
                    Write-Output $obj
                    throw "No ZipCode or City specified or couldn't determine your GEOLocation. Exiting"
                }
            } catch {
                $Properties = @{City = $Null
                    Country          = $Null
                    Latitude         = $Null
                    Longitude        = $Null
                    SunRise          = $Null
                    SunSet           = $Null
                    CurrentWeather   = $Null
                    NowTemperature   = $Null
                    HighTemperature  = $Null
                    LowTemperature   = $Null
                    Humidity         = $Null
                    Clouds           = $Null
                    Rain             = $Null
                    Wind             = $Null
                    WindSpeed        = $Null
                    WindDirection    = $Null
                    Pressure         = $Null
                }
                $obj = New-Object -TypeName psobject -Property $properties
                Write-Output $obj
                throw "No ZipCode or City specified or couldn't determine your GEOLocation. Exiting"

            }
        }
    }
    process {
        try {
            [xml]$APIRequest = Invoke-WebRequest -Uri $APIPath
            $Response = $APIRequest.current

            if ($Unit -eq 'Imperial') {
                $NowTemp = "$($Response.temperature.value)*F"
                $HighTemp = "$($Response.temperature.max)*F"
                $LowTemp = "$($Response.temperature.min)*F"
                $WindSpeed = "$($Response.wind.speed.value) Mph"
            } elseif ($Unit -eq 'Metric') {
                $NowTemp = "$($Response.temperature.value)*C"
                $HighTemp = "$($Response.temperature.max)*C"
                $LowTemp = "$($Response.temperature.min)*C"
                $WindSpeed = "$($Response.wind.speed.value) Kph"
            } elseif ($Unit -eq 'Standard') {
                $NowTemp = "$($Response.temperature.value)*K"
                $HighTemp = "$($Response.temperature.max)*K"
                $LowTemp = "$($Response.temperature.min)*K"
                $WindSpeed = "$($Response.wind.speed.value) m/s"
            }

            $Properties = @{
                City            = $Response.city.name
                Country         = $Response.city.country
                Latitude        = $Response.city.coord.lat
                Longitude       = $Response.city.coord.lon
                SunRise         = $Response.city.sun.rise
                SunSet          = $Response.city.sun.set
                CurrentWeather  = $Response.weather.value
                NowTemperature  = $NowTemp
                HighTemperature = $HighTemp
                LowTemperature  = $LowTemp
                Humidity        = "$($Response.humidity.value) $($Response.humidity.unit)"
                Clouds          = $Response.clouds.name
                Rain            = $Response.precipitation.mode
                Wind            = $Response.wind.speed.name
                WindSpeed       = $WindSpeed
                WindDirection   = "$($Response.wind.direction.value)* $($Response.wind.direction.name)"
                Pressure        = "$($Response.pressure.value) $($Response.pressure.unit)"
            }

        } catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Output $Response.ChildNodes
            Write-Error "$FailedItem responded with $ErrorMessage"
            $Properties = @{
                City            = $Null
                Country         = $Null
                Latitude        = $Null
                Longitude       = $Null
                SunRise         = $Null
                SunSet          = $Null
                CurrentWeather  = $Null
                NowTemperature  = $Null
                HighTemperature = $Null
                LowTemperature  = $Null
                Humidity        = $Null
                Clouds          = $Null
                Rain            = $Null
                Wind            = $Null
                WindSpeed       = $Null
                WindDirection   = $Null
                Pressure        = $Null
            }
        } finally {
            $obj = New-Object -TypeName psobject -Property $properties
            Write-Output $obj
        }
    }
}
