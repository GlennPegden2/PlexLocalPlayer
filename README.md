#PlexLocalPlayer

So, imagine a scenario where you're trying to give a presentation on a customer's PC, what you are trying to show is a video on a remote Plex server, but the customer's PC is so locked down (whitelisted apps only) that whilst vlc will work, a web browser won't! Seriously!!!

However, powershell did work and that gave me a way in.

So, what I thought wouldtake just a few simple lines to download the file from the plex server and play it through vlc, actually became a bit of an epic.

Therefore, in case anybody ever gets stuck in the same hole or wants some sample code demonstrating to do take "streamed" content and convert it back into something a media player will play locally. The code is now on github at https://github.com/glennpegden/PlexLocalPlayer

To use it just pass in the URL of the video details page in Plex, your plex username andpassword and the foldername to dump the video into (also optionally the paths to ffmpeg and vlc, or you can redefine these at the top of the script)

e.g.
.\PlexLocalPlay.ps1 "http://app.plex.tv/web/app#!/server/01380a5c2c9b4290-9c1136b6882a65c1/details/%2Flibrary%2Fmetadata%2F12345" "user@email.com" "yourplexpasswrd" "G:\Users\Glenn\Downloads"


*Disclaimer: I've no idea if interacting with Plex is this way is against their terms and conditions. I'm also not sure any of how I'm doing it is "the right way" because it was reverse engineered by examining how the Plex Web Player works on a laptop rather than from any official documentation. I'm also not responsible for how you use it. My use case was to download marketing material that I was allowed to distribute, I imagine doing this with your family's blu ray connection may be illegal in many places.*

