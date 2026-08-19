# DotA 2 Bot Script: Tinkering ABo(u)t [7.41e] (ryndrb)

This is a DotA 2 Bot Script based on [Beginner:AI NEW](https://steamcommunity.com/sharedfiles/filedetails/?id=1627071163); it's mainly for personal use.
This is where I update this script. I very rarely, if ever, update the Steam Workshop page.

Since this is an inherently R-B system, the best viable way to make bots "challenging" is through aura stacking. Evasion, damage reduction, and aura items tend to be on the stronger side
in bot games. Though if there are multiple decent human players vs bots, it won't really matter much. Also, performance can still be hit or miss depending on the team composition. Point-Click AoE heroes are good.

Worth noting that I've also made a [vscript](https://github.com/ryndrb/dota2bot/tree/master/Buff) to boost bots GPM and XPM in All Pick mode, and they can get Neutral Items too. This is recommended to use.

If you’ve come across this script or is using it, good feedback is always welcome. Drop any suggestion on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3139791706) page or open an Issue / PR.

- ***To Use***
    - Since Valve hasn't fixed the workshop bug yet, bot scripts (that were uploaded after? the bug occured) are only playable through `Local Host` lobby.
    - To use this:
        - Go to `Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts`. You will see that there is a `bots` folder inside. Either delete this folder or rename it.
            - Once you've deleted or renamed the bots folder, create a new folder called `bots`.
            - Download the files on this repo by going to `<> Code` and Under `Local`, select `Download ZIP`.
            - Extract the contents of the zip inside the `bots` folder.
            - Alternatively, if you know how to use Git, just clone/pull this inside the `bots` folder.
        - Then, launch DotA 2.
        - Click `Play Dota`. Under `Custom Lobbies`, select `Create`.
        - Under the `Lobby Settings` at the bottom, select `Edit`. Then, in the drop down `Radiant Bots` and `Dire Bots` menus, select `Local Dev Script`.
            - It's meant to play itself as it's built that way.
        - The `Server Location` must be `Local Host`.
        - Click OK, and it should be good to go. Bot names should be in hiragana (ie. あ).
            - Note: All playing humans should only play on one team.
            - The lobby has 5 slots:
                -  1st is for Position 2 (Mid Lane)
                -  2nd is for Position 3 (Off Lane)
                -  3rd is for Position 1 (Safe Lane)
                -  4th is for Position 5 (Support Safe Lane)
                -  5th is for Position 4 (Support Off Lane)
        - (For non-Git) Everytime there is an update, you have to re-download the files and replace the ones on the `bots` folder. If you've made personal changes to some files, you have to make a backup to those files, or fix the conflicts yourself.
        - Note: Since this uses the user's own computer as the server (Lobby) to work properly, there will be FPS issues. Valve making bot scripts run on their servers again is the ultimate solution.
    - How I test:
        - Bots v Bots
        - `Enable Cheats`
        - Type: `sv_cheats 1` in console.
        - Type: `host_force_frametime_to_equal_tick_interval 1` in console.
        - Type: `host_timescale 4` in console for speedup. `host_timescale 0` to pause.
        - Type: `script_reload_code bots/Buff/buff` in console (pick phase).

- ***Key Scripts***
    - BOT Experiment (by Furiouspuppy)
    - ExtremePush (https://github.com/insraq/dota2bots)

- ***Optional External AI Backend***
    - This repo includes an experimental localhost AI bridge. Lua remains the in-game executor, while an optional Docker backend can make high-level movement and attack decisions.
    - The bridge is configured in `AIBackend/config.lua`. It is enabled for player ID `0` by default; add IDs `0` through `9` to `controlled_player_ids` to control more bots.
    - Start the sample backend from this folder:
      ```powershell
      docker compose up --build
      ```
    - The backend listens on `http://127.0.0.1:8765`. With `AI_POLICY_MODE=none`, every decision is `none` and the existing Lua scripts keep full control. For quick smoke tests, set `AI_POLICY_MODE=attack_nearest_enemy` or `AI_POLICY_MODE=move_forward`.
    - Scale worker processes by changing `AI_WORKER_COUNT` in `docker-compose.yml`, up to `10`. Requests are routed by bot player ID, so each bot can be handled independently.
    - If the backend is stopped, times out, or returns an invalid action, the bot falls back to the existing Lua mode logic.

- ***Heroes (Pos: 1,2,3,4,5)***
    - <ins>Heroes Implemented Count:</ins> **127** / 127
    - Bugged (due to Valve; some can be relatively weak)
        - Dark Willow
        - Elder Titan
        - Hoodwink
        - IO
        - Kez
        - Marci
        - Muerta
        - Primal Beast
