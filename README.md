# Junk Jet

A Garry's Mod tool that lets you launch random junk and entities at high speed. Perfect for chaos, testing, or just having fun.

## Features

- Launch a variety of props and entities with adjustable speed.
- Right‑click any physics prop or entity to add/remove it from your personal launch pool.
- Console commands for managing your pool manually.
- Optional fire mode.
- Optional slippery mode.
- Optional dissolve mode with adjustable timer.
- Prop scaling support.
- Sawblade special behavior: spawns as a thrown sawblade, exactly like the gravity gun in Half‑Life 2 (slices enemies, sticks into walls, spins dangerously).

## Installation

You can subscribe on the Steam Workshop, or if you prefer to install manually, follow these instructions:

1. Download or clone this repository into your Garry's Mod `addons` folder.
2. Ensure the folder is named `junkjet` (or any name you prefer) and contains the files are directly inside it.
3. Restart Garry's Mod or run `menu_cleanupgmas` in console if needed.
4. The tool will appear under **Tools > Fun + Games > Junk Jet**.

## File Structure

junkjet/
└── lua/
└── weapons/
└── gmod_tool/
└── stools/
└── junkjet.lua

No extra models or materials are required – everything uses base Garry's Mod assets. The add-on also supports launching custom content, but use at your own risk.

## Usage

- **Left‑click**: Launch a random item from your current pool.
- **Right‑click**: Scan the entity you're looking at. If it's a `prop_physics` or `sawblade_thrown`, its model is added/removed from your prop pool. For any other entity, its class name is added/removed from your entity pool.

### Console Commands

| Command                  | Description                                       |
|--------------------------|---------------------------------------------------|
| `junkjet_addprop <model>`| Adds a prop model to your launch pool.            |
| `junkjet_removeprop <model>` | Removes a prop model from your launch pool.   |
| `junkjet_addentity <class>` | Adds an entity class to your launch pool.      |
| `junkjet_removeentity <class>` | Removes an entity class from your launch pool.|
| `junkjet_clearitems`     | Clears both your prop and entity pools.           |

*Note: Your personal pools are saved per‑player and persist until you leave the server or clear them.*

## Configuration

The following settings are available in the tool's context menu:

- **Fire Mode**: Ignites launched objects.
- **Slippery Mode**: Gives launched physics objects an `ice` material.
- **Dissolve Mode**: Automatically dissolves launched objects after a set time.
- **Launch Speed**: Multiplier for launch force.
- **Prop Scaling**: Scales props on launch.
- **Dissolve Speed**: Time in seconds before dissolution.

## Default Launch Pool

The addon ships with a default list of props and entities. Right‑click scanning can modify your personal copy. To restore defaults, simply clear your pool (`junkjet_clearitems`) – the tool will fall back to the default lists.

## Contributing

Pull requests are welcome. If you find bugs or have suggestions, please open an issue.
