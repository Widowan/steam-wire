Since new steam recordings feature on linux captures entire system audio instead of just the game, this wireplumber script will automatically replace sink device steam is listening with wine64-preload

## How it works
When you launch any wine/proton app (binary of "wine64-preloader"), this script then starts looking for any steam input nodes* and disconnects any `Audio/Sink` nodes from it; after that it connects launched wine app to found steam input nodes.

> [!TIP]
> *Note that this does NOT include any micrphone activites such as steam voice chats, streaming, etc., as those are considered Chromium's RecordStream.

### Caveats
> [!IMPORTANT]
> - This does NOT work with native games. If you launch native game by itself, it won't do anything - steam will still listen to your system audio (imo better than no audio at all).
> - Launching multiple games at the same time can lead to unexpected behavior; if you mix native and wine games, the behavior will be even more unepexcted and native game will probably have no audio in the recording


## Installation

Put 90-steam-wire.conf in your `~/.config/wireplumber/wireplumber.conf.d/` and steam-wire.lua in your `~/.local/share/wireplumber/scripts/` (create if doesn't exists) and restart wireplumber/log out of your session.

```
systemctl restart --user wireplumber.service
```

---

P.S. [Wireplumber's documentation sucks](https://blog.wido.dev/wireplumber-scripting)
