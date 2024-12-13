Since new steam recordings feature on linux captures entire system audio instead of just the game, this wireplumber script will automatically unlink you sink nodes (output devices) from steam and link wine64-preloader instead.

> Keep in mind, this will **NOT** work with native games (that do not run through proton); it will instead just remove the audio from recording entirely.

Put 90-steam-wire.conf in your `~/.config/wireplumber/wireplumber.conf.d/` and steam-wire.lua in your `~/.local/share/wireplumber/scripts/` (create if doesn't exists) and restart wireplumber/log out of your session.

```
systemctl restart --user wireplumber.service
```

P.S. [Wireplumber sucks](https://blog.wido.dev/wireplumber-scripting)
