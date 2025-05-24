# Arr-on-Deck
*Pirates hear that a lot on deck.*

Want to watch movies and shows in a really good quality, without having to manually look for and download them (and their subtitles) whenever they release, all without leaving the couch? Then this is for you. 

This is a rootless media stack that uses qBittorrent to download media you put on your Plex Watchlist through a VPN with kill-switch.

**No programs need to be installed.** `sudo` is only used to set up user groups and permissions.

For me, setting this up took way too much time. As a result, I created this with the hope that it will save others a lot of hassle. I also tried to make the installation as easy as possible, so almost everybody can do it.

## What's New
### 2025-05-24
SteamOS 3.7.8 updated some libraries, which require us to make some changes.

Open the terminal in inside the container directory (where `start.sh` resides) and run `git pull origin main`.

Then change the URL used for qBittorrent inside Sonarr and Radarr to `localhost`.

## What does it do?
### Downloading
This will take care of downloading media through a VPN automatically.

Sonarr and Radarr can follow movies and shows, so they will be downloaded whenever they are available.

Obviously, this should only be used for legal purposes, such as downloading public domain or freely licensed media. The VPN prevents others from knowing what you are watching.

### Streaming
It also sets up Plex as a media server, so you can watch from anywhere.

It will allow you to watch your content using Plex HTPC (a nice controller friendly UI) while inside the Deck's Gaming Mode.

If you have Plex pass (a sort of Premium), it could skip intro and credits for you.

## Install
1. Push the `Steam` button.
1. Select `Power > Switch to Desktop`.
1. Click on the bottom left button (Steam Deck icon).
1. Search for `Discover`.
1. Open it.
1. Search for `Plex HTPC`.
1. Install it.
1. Click again on the Steam Deck icon.
1. Search for `Plex HTPC`.
1. Right click on it.
1. Choose `Add to Steam`.
1. Create a Plex account.
1. Download this repository.
1. Extract it. (`Right click` on it.)
1. Find a VPN provider that supports Wireguard (most do).
1. Download a Wireguard config from the provider.
1. Place it here: `conf/wireguard/wg0.conf` (rename if necessary)
1. Open a terminal in the extracted folder. (Right click inside the folder and choose `Open Terminal Here`.)
1. Run `chmod +x setup.sh`.
1. Run `passwd` to choose an administrator password.
1. Make sure your media hard drive is mounted. (To automatically mount it, modify `script_customize/before-start.sh`.)
1. Then run `./setup.sh`.
1. After that run `./start.sh`.
1. Then follow the rest of this README file.

## URLs
When they all are running, you should be able to visit these:

| Service     | Manages      | URL                                                |
|-------------|--------------|----------------------------------------------------|
| qBittorrent | Torrents     | [http://steamdeck:8180/](http://steamdeck:8180/)   |
| Sonarr      | Shows        | [http://steamdeck:8989/](http://steamdeck:8989/)   |
| Radarr      | Movies       | [http://steamdeck:7878/](http://steamdeck:7878/)   |
| Prowlarr    | Indexer      | [http://steamdeck:9696/](http://steamdeck:9696/)   |
| Bazarr      | Subtitles    | [http://steamdeck:6767/](http://steamdeck:6767/)   |
| Plex        | Media Server | [http://steamdeck:32400/](http://steamdeck:32400/) |


The number after `steamdeck:` is the port of the application.

## API keys
1. Open a text editor. (Click on the Steam Deck icon and search for `Kate`.)
1. For Sonarr and Radarr, go into `Settings > General > Security`.
1. Copy the API key and paste it into the editor.
1. Write the name before each, so you don't mix them up.

## Importing quality profiles and custom formats
If your setup does not support 4K (2160p), or you simply want to save space, you should comment out the lines in `copy_to_conf/recyclarr/recyclarr.yml` that contain a higher resolution then the one you want to download.

Run `recyclarr-update.sh`.

After that has succeeded, do the following for Radarr, if you would like to prefer the original language of movies:
1. Go to `Settings > Profiles`.
1. Click on `Up to 4K Bluray or WEB with Anime`
1. Set `Language` to `Original`.

## Connecting *arrs to each other
1. Open Prowlarr
1. In `Settings > Apps` add Radarr and Sonarr.
1. Paste the respective API key and use these URLs:

* Prowlarr Server URL is `http://host.containers.internal:9696`
* Radarr Server URL is `http://host.containers.internal:7878`
* Sonarr Server URL is `http://host.containers.internal:8989`

In Bazarr you have to do the same for Sonarr and Radarr. Make sure to use `host.containers.internal` as the host and the respective port in the settings.

## qBittorrent
Open the WebUI and login. The user should be `admin`.

If you don't know the password, run `podman logs qbittorrent` and there you should find the initial one.

In `Settings > Downloads` the `Default Save Path` should be `/data/torrent`.

In `Settings > Tags & Categories` (or on the left panel if you're using the default WebUI) create two categories:

* One should be called `radarr` with a `save path` of `movie`.
* And one should be called `tv-sonarr` with a `save path` of `show`.

In `Settings > Advanced` look for the `Network` section and set the `Network interface` to `wg0` (wireguard).

In `Settings > Bittorent` you may enable `Seeding limits` if you like, but don't choose `Remove torrent`, because Sonarr or Radarr need it to stay inside the download client. It may be removed before they have imported it. Instead, choose `Stop torrent`.

If you chose the Vuetorrent UI during the `setup.sh` go to `Settings > WebUI`:
1. Check `Use alternative WebUI`
1. Set the path to `/vuetorrent`

## Bazarr
Enable the languages you want to have as subtitles in `Settings > Languages`.

## Prowlarr
### Add Indexers
The indexers are configured through Prowlarr. They synchronize automatically to Radarr and Sonarr.

Choose and enable some indexes. (Look online for popular ones.)

## Sonarr und Radarr
### Connecting a download client
1. Go to `Settings > Download clients` and click on the plus button.
1. Look for `qBittorrent`.
1. Click on it.
1. Set the `Host` to `host.containers.internal` and `Port` to `8180`. Enter username and password.
1. Depending on whether this is Sonarr or Radarr, set the respective `Category` that we defined in the qBittorrent section.
1. Press the Test button.
1. Go to `Settings > Management` for Sonarr and Radarr.
1. In Sonarr, set the Root folder to `/data/media/show`. 
1. In Radarr, set the Root folder to `/data/media/movie`.

### Connecting Plex
1. Go to `Settings > Import List` click the plus button.
1. Look for `Plex Watchlist`.
1. Click on it.
1. Set `Quality Profile` to `Up to 4K Bluray or WEB with Anime`
1. Check `Enable Automatic Add` and `Search for Missing Episodes`.
1. You can choose how much you want to monitor (and thus download).
1. Click the `authenticate` button.

## Done
You are done. Enjoy!

## Optional steps
### Autostart of pods and management WebUI (optional)
In the future to run the media stack, just run `./start.sh`.

However, if you want that to happen automatically on start and have a nice webUI for executing these scripts, run `install-arr-on-deck-manager-service.sh`.

### Deck: Stay always on
If you want to use the Deck as an always-on media system, it is better to not allow it to sleep. (I know this is mean.)

In `Gaming Mode` do the following:

1. Push the `Steam` button
1. Select `Settings > Display`
1. Scroll down to the `Put Deck to sleep` section:
1. Set `When plugged in, sleep after...` to `Disabled`

## How To
### Copy existing media into the media directories
If you copy new files in the `movie` or `show` folder, you may have to run `ensure-permissions.sh` to make sure that the container are allowed to read these files.

### Sonarr and Radarr: Rename folders (not files)
1. Click on `Movies` / `Series`
1. Click `Edit Movies` / `Select Series`
1. Click `Select All` (or whatever you like)
1. Click the `Edit` button
1. Click on `Root Folder` drop down
1. Choose the same root folder that you already use (should be in the drop down)

### Sonarr: Unmonitor seasons or episodes
Click the icon next to the Season number to toggle monitoring for all episodes or none. After that, choose the specific episodes you want to monitor.

### Sonarr: Manual import
To manually import files from multi season pack (or else) go to `Wanted > Missing` and select the folder you want to import and choose interactive import. You have to do this for each season.

### Bazarr: Multiple languages
If you want multiple languages to be downloaded, set the cutoff to `nothing`. If it is `Any`, click on it in the drop down menu.

### Plex: Assorted settings
Disable Plex-provided content here: http://steamdeck:32400/web/index.html#!/settings/online-media-sources

If you always want the best quality and not stream outside your local network, go to http://steamdeck:32400/web/index.html#!/settings/web/general and look for `Transcoder` and check `Disable video stream transcoding`.

In `Settings > Library` you may want to set `Video played threshold` to `95%`. For me episodes where being marked as watched, when they were not actually finished.

### Plex: Prefer Audio/Subtitle Language
1. Open http://steamdeck:32400/web/index.html#!/settings/account
1. Then click on `Languages`.
1. Enable `Automatically select audio and subtitle tracks`.
1. Set `Prefer audio tracks in` to `None` (so the default is used).
1. Set `Subtitle mode` to `Always enabled`.
1. Set `Prefer subtitles in` to `English`.

### Plex: Mark all as watched
First select an item then scroll all the way down, and then shift click the select button on the last movie. This should select all items. Then mark them as watched.

### Plex HTPC: Set audio for whole show
In the show's page, go to `Edit Menu (Marker Icon) > Advanced Tab (bottom of)` and set the `Preferred Audio Language & Preferred Subtitle Language`.

### Podman: Clean up container images
Run `podman system reset`. After that images have to be re-downloaded, but your data and config will stay.

However, cleaning up is not really necessary, unless you lack disk space. 

## Troubleshooting
### HDD
When the hard drive where the media data is stored is disconnected and reconnected, a restart of the containers is required, as the respective volumes don't work anymore.

### Plex
If you're getting double / wrong events with one of your controllers, you can run the `disable-plex-controller-support.sh` script. 

It basically disables the native controller support in Plex HTPC, so that Steam Input can take care of it.

Of course then your controller config must not contain controller inputs like the `A` button.

## Explanation of Quality and Formats
"Quality Profiles" allow you to select the quality of a movie or show you want to download. They feature "Custom Formats," which fine-tune your release selection based on specific keywords or patterns in release names.

As a result, they can be used to limit downloads to specific languages. You can also specify that you want downloads to be upgraded when a better version appears.

You can also set a minimum score for a release to be downloaded. Each release is scored, and only those meeting the minimum score are downloaded. A release may receive +2 for 5.1 sound and +1 for being 2160p (total 3). A movie with 2 points would be preferred over one with 1.
