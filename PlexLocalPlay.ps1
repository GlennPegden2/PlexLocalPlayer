[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)] [string]$UIURL,
  [Parameter(Mandatory=$True)] [string]$username,
  [Parameter(Mandatory=$True)] [string]$password,
  [Parameter(Mandatory=$False)] [string]$OutputFolder,
  [Parameter(Mandatory=$False)] [string]$ffmpeg = "G:\ffmpeg\ffmpeg-20170214-8fa18e0-win64-static\bin\ffmpeg.exe",
  [Parameter(Mandatory=$False)] [string]$vlc = "D:\apps\VideoLAN\VLC\vlc.exe"
  
)

function Get-PlexAuthTokn ($username, $password) {

	$auth = Invoke-WebRequest -Uri "https://plex.tv/users/sign_in.json" -Method Post -Body @{'user[login]'=$username ; 'user[password]'=$password ;} -Headers @{'X-Plex-Product'='Plex Web' ; 'X-Plex-Version'='37.0' ; 'X-Plex-Client-Identifier'="$guid" ; }
	
	if ($auth.statusCode -ge 200 -and $auth.statusCode -lt 300 ) {
		$content = ConvertFrom-Json $($auth.content)
		return $content.user.authtoken
	} else {
		return $null
	}
	
}

function Get-PlexServers ($token) {

	$servers = Invoke-WebRequest -Uri "https://plex.tv/pms/servers.xml?X-Plex-Client-Identifier=unique_id&X-Plex-Product=Plex+Web&X-Plex-Device=OSX&X-Plex-Platform=Chrome&X-Plex-Platform-Version=37.0&X-Plex-Version=2.2.4&X-Plex-Device-Name=Plex+Web+(Chrome)&X-Plex-Token=$token"

	if ( $servers.statusCode -ge 200 -and $servers.statusCode -lt 300 ) {
		$content = [xml]$servers.content
		return $content.MediaContainer.Server
	} else {
		return $null
	}
	
}

function Get-PlexResources ($token) {

	$resources = Invoke-WebRequest -Uri "https://plex.tv/api/resources?includeHttps=1&includeRelay=1&X-Plex-Client-Identifier=unique_id&X-Plex-Product=Plex+Web&X-Plex-Device=OSX&X-Plex-Platform=Chrome&X-Plex-Platform-Version=37.0&X-Plex-Version=2.2.4&X-Plex-Device-Name=Plex+Web+(Chrome)&X-Plex-Token=$token"

	if ( $resources.statusCode -ge 200 -and $resources.statusCode -lt 300 ) {
		$content = [xml]$resources.content
		return $content.MediaContainer.Device
	} else {
		return $null
	}
	
}

function Get-PlexFileMetadata ($metaDataURL) {

	$metadata = Invoke-WebRequest -Uri $metaDataURL

	if ( $metadata.statusCode -ge 200 -and $metadata.statusCode -lt 300 ) {
		$content = [xml]$metadata.content
		return $content.MediaContainer
	} else {
		return $null
	}


}


function  Get-PlexUIURLParts ($url) {

	$uri = [System.Uri]$url
	$fragment = $uri.fragment -split "/"

	if ($uri.Authority -ne "app.plex.tv") {
		Write-Error "URL doesn't look right - wrong domain (Expected app.plex.pv got $($uri.Authority))"
		return $null
	} elseif ((($uri.segments[1] -ne "web/") -or ($uri.segments[2] -ne "app")) -and ($uri.segments[1] -ne "desktop") ) {
		Write-Error "URL doesn't look right - wrong path"
		return $null
	} elseif (($fragment[1] -ne "server") -or ($fragment[3].Substring(0,7) -ne "details")) {
		Write-Error "URL doesn't look right - wrong fragment"
		return $null
	} else {
		$metadataid_t = $fragment[3] -split "\?"
        $metadataid_l = $metadataid_t[1] -split "%2F"
        $metadataid = $metadataid_l[3] -split "&"
        return $fragment[2],$metadataid[0]
	}

}

function Get-PlexConnectionsForServer ($serverid , $resources, $metadataid) {
	$conList =@()

	
	$server = $resources | Where clientIdentifier -eq $serverid
	
	$connectList = $server.connection | Where local -EQ 0
	
	foreach ($connection in $connectList) {
			
		$conInfoProps = @{
			'host'=$($connection.uri); 
			'remoteToken'=$($server.accessToken) ; 
			'startURL'="$($connection.uri)/video/:/transcode/universal/start?hasMDE=0&path=http%3A%2F%2F127.0.0.1%3A32400%2Flibrary%2Fmetadata%2F$metadataid&mediaIndex=0&partIndex=0&protocol=http&fastSeek=1&directPlay=0&directStream=0&subtitleSize=100&audioBoost=100&location=wan&session=$sessionid&offset=0&subtitles=burn&copyts=1&Accept-Language=en-GB&$stdplexmeta&X-Plex-Token=$($server.accessToken)" ;
			'pingURL'="$($connection.uri)/video/:/transcode/universal/ping?session=$sessionid&$stdplexmeta&X-Plex-Token=$($server.accessToken)" ;
			'metaDataURL'="$($connection.uri)/library/metadata/$($metadataid)?checkFiles=1&includeExtras=1&includeRelated=1&includeRelatedCount=5&includeOnDeck=1&includeChapters=1&includePopularLeaves=1&includeConcerts=1&includePreferences=1&$stdplexmeta&X-Plex-Token=$($server.accessToken)" ;

		}
		$conInfo = new-object -TypeName PSObject -Property $conInfoProps
		$conList += $conInfo
	}

	return $conList

}


function Start-PlexDownloader ($url, $targetFile) {
	Write-Verbose "Dowloading $startURL"
	Start-Job -ScriptBlock {
	
		$uri = New-Object "System.Uri" "$using:url" 
	    $request = [System.Net.HttpWebRequest]::Create($uri) 
	    $request.set_Timeout(15000) 
	    $response = $request.GetResponse() 
	    $responseStream = $response.GetResponseStream() 
	    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $using:targetFile, Create 
	    $buffer = new-object byte[] 10KB 
	    $count = $responseStream.Read($buffer,0,$buffer.length) 
	    $downloadedBytes = $count 
	    while ($count -gt 0) 
	    { 
			$fileSize = [System.Math]::Floor($downloadedBytes)
			Write-Output "$filesize"

			$targetStream.Write($buffer, 0, $count) 
	        $count = $responseStream.Read($buffer,0,$buffer.length) 
	        $downloadedBytes = $downloadedBytes + $count 
	    } 
	    $targetStream.Flush()
	    $targetStream.Close() 
	    $targetStream.Dispose() 
	    $responseStream.Dispose() 
			
	}
}



function Invoke-PlexDownload ($conList,$tmpFile,$OutputFolder) {
	foreach ($connection in $conList) {

		$fileMetaData = Get-PlexFileMetadata $($connection.metaDataURL)
		$remoteFile = $fileMetaData.Video.Media.Part.file
		$filename =  Split-Path $remoteFile -leaf
		$localFile = "$OutputFolder\$filename"
		$fileSize = $fileMetaData.Video.Media.Part.size

		Write-Host "Trying to download $remoteFile from $($connection.host)"

		$job = Start-PlexDownloader $connection.startURL $tmpFile 

		#Needed as the ping check will 404 at first until the server has done it's thing preparing the download
		Start-Sleep -s 5

		while ((Get-Job -Id $job.id).state -eq "Running"  ) {
			try { $response = Invoke-WebRequest -Uri "$($connection.pingURL)" -Verbose:$false } 
			catch { 
				$errcode = $_.Exception.Response.StatusCode.Value__
				Write-Host "keep-alive ping returned $errcode - $($connection.pingURL)" 
				$reponse = $_.Exception.Response
			}
			
			Write-verbose "keep-alive ping to $($connection.host) returned $($response.statuscode)"
					
			$dlstatus = Receive-Job -job $job
			$dlarray = $dlstatus -split("\r\n")
			$lastline = $dlarray[-1]
			$percentage = ([int64]$lastline / [int64]$fileSize) * 100 
			if ($percentage -lt 100) {
				Write-Progress -Activity "Downloading $filename" -Status "$lastline of very roughly $fileSize ($("{0:N0}" -f $percentage)%)" -PercentComplete $percentage
			} else {
				Write-Progress -Activity "Downloading $filename" -Status "$lastline of very roughly $fileSize ($("{0:N0}" -f $percentage)%) - Hey this is an imprecise art!" -PercentComplete -1 
			}
			Start-Sleep -s 15
		}
		
		Write-Progress -Activity "Downloading $filename" -Status "Completed" -Completed 
		
		$tmpFileSize = (Get-Item $tmpFile).length
		if ($tmpFileSize -gt 0 ) {
			if ($tmpFileSize -lt $fileSize) {
				Write-Warning "Temp file $tmpFile is smaller than expected ($fileSize). "
			}

			return $true,$localFile
		}
				
				
	}

	Write-Host "all download links failed :("
	$null
}

function Invoke-PlexContainerFix ($ffmpeg,$tmpfile,$dlfile) {
	Write-Host "Calling ffmpeg to fix container for $dlfile"
	Write-Verbose "running $ffmpeg -i $tmpfile -c copy $dlfile -y" 
	Start-Process -FilePath "$ffmpeg" -ArgumentList "-i `"$tmpfile`" -c copy `"$dlfile`" -y" -NoNewWindow -wait
}

function Invoke-VLC ($playerPath,$fileName) {
	Write-Host "Calling VLC for $fileName"
	Write-Verbose "running $playerPath $fileName" 
	Start-Process -FilePath "$playerPath" -ArgumentList "`"$fileName`"" -NoNewWindow -wait
}


$global:guid = [guid]::NewGuid()
$global:sessionid = [guid]::NewGuid()
$global:stdplexmeta = "X-Plex-Product=Plex%20Web&X-Plex-Version=2.13.0&X-Plex-Client-Identifier=$guid&X-Plex-Platform=Chrome&X-Plex-Platform-Version=56.0&X-Plex-Device=Windows&X-Plex-Device-Name=Plex%20Web%20%28Chrome%29&X-Plex-Device-Screen-Resolution=1920x901%2C1920x1080"
$tmpfile=[System.IO.Path]::GetTempFileName()

$token = Get-PlexAuthTokn $username $password
$resources = Get-PlexResources $token
$serverid, $metadataid = Get-PlexUIURLParts $UIURL
$conList = Get-PlexConnectionsForServer $serverid $resources $metadataid
$downloadStatus,$filename = Invoke-PlexDownload $conList $tmpfile $OutputFolder
if ($downloadStatus) {
	if (Invoke-PlexContainerFix $ffmpeg $tmpfile $filename) {
		Invoke-VLC $vlc $filename
	}
}
