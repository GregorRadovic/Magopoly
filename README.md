# Magopoly

Monopoly, plus a deck of spell cards.

Magopoly plays like the classic board game: roll, move, buy property, collect
rent, and try not to go bankrupt. But there's a twist: every time you pass Go you also draw a
**spell card**. Spells bend the usual rules: change your roll to dodge a tax
space, force a trade, drain an opponent's cash, build houses without owning the
full colour set, summon a fifth railroad. You cast them using *Attunement* -
one point per unmortgaged property you own of that spell's color - so the power of your spells is
directly proportional to the properties you own.

Built in **Godot 4.7** (GDScript). Runs on integrated graphics and older
machines (OpenGL / Compatibility renderer).

<!-- Add a screenshot here once you have one:  ![Magopoly](docs/screenshot.png) -->

## Features

- **1–8 players**, any mix of humans and computer opponents
- Fully supported **online multiplayer** with safeguards against disconnection
- **40 spell cards**, most with three tiered effects, with more expansions coming soon
- Multiple **Pause Options** to fine-tune your ability to react with spells on your opponents' turns
- **Quickstart / BlitzStart** modes where everybody starts with properties and spells for a faster game
- Guided **Tutorial** and in-game **rulebook viewer**
- **Settings** to adjust resolution and in-game volume

## Play

### Download a build (no Godot needed)

Grab the latest `Magopoly.zip` from the
[**Releases**](https://github.com/GregorRadovic/Magopoly/releases) page, unzip
it, and run `Magopoly.exe` (64-bit Windows 10/11).

The build is unsigned, so Windows SmartScreen shows *"Windows protected your
PC"* the first time; click **More info → Run anyway**. A few antivirus tools
also flag unsigned Godot builds as a false positive; whitelist it if needed.

*(If there's no release yet, follow the instructions below to run from source.)*

### Run from source

1. Install the **Godot 4.7** editor (standard edition). <https://godotengine.org/download>
2. Clone this repo.
3. Open `project.godot` in Godot and let it import the assets.
4. Press **F5** (or the ▶ button). No export templates required.

## Multiplayer

One player picks **Host Game**; everyone else picks **Join Game** and types in
the host's address. It's a direct connection on **UDP port 27015**; there's no
matchmaking server.

- **Same network (same house / Wi-Fi):** joiners use the host's **local
  address**; the Host Game screen shows it, with a Copy button.
- **Over the internet:** joiners use the host's **public address** (also shown
  on the Host Game screen). The host must **port-forward UDP 27015** to their PC
  and allow it through the firewall. If port-forwarding isn't an option, a
  LAN-emulation VPN like Tailscale works; everyone joins the virtual network
  and uses the host's VPN address.

The host stays authoritative for the whole match. If a player drops, an AI holds
their seat until they rejoin with **Join Game** (their address is pre-filled).

## Credits

- **Programming:** Gregor Radovic (<https://github.com/GregorRadovic>)
- **Music:** *"The Britons"* by Kevin MacLeod (incompetech.com), licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Art:** Individual artists are credited on their cards. Card layouts were
  generated with [Magic Set Editor](https://magicseteditor.boards.net/).

## Legal

This is a free, non-commercial fan-made project created for entertainment and educational purposes. It is not affiliated with, endorsed by, sponsored by, or licensed by Hasbro, Inc.

**MONOPOLY®**, the MONOPOLY name and logo, the distinctive MONOPOLY gameboard design, Mr. Monopoly, and other related trademarks and distinctive elements are the property of Hasbro, Inc. and/or its licensors. All rights in those materials are reserved by their respective owners.

Magic: The Gathering®, including its card artwork, card names, characters, symbols, and other related intellectual property, is the property of Wizards of the Coast LLC and/or its licensors. All rights in those materials are reserved by their respective owners.

This project does not claim ownership of any Hasbro or Wizards of the Coast trademarks, copyrighted artwork, characters, card artwork, or other intellectual property.

This project is distributed free of charge and is not intended to suggest any affiliation with or endorsement by Hasbro, Inc.

If you are a rights holder and believe material in this repository infringes your rights, please contact the repository maintainer.
