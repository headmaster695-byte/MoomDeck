# MoomDeck

MoomDeck is a pseudo-OS for **CC:Tweaked** on **Minecraft 1.21.1 NeoForge**. It provides a graphical desktop for monitoring resource inflow and outflow from peripherals — including items, fluids, FE (Forge Energy), and Create Stress Units (SU) — with automatic rate calculation and factory/machine organization.

## Features

- **Graphical desktop UI** on the computer screen or an attached monitor
- **Automatic peripheral discovery** via wired modems
- **Adapter support** for:
  - CC:Tweaked generic peripherals (`inventory`, `fluid_storage`, `energy_storage`)
  - **CC:C Bridge** `create_target` display-link text parsing
  - **Advanced Peripherals** `energy_detector`, `inventory_manager`
  - **Create** stressometer (`getStress` / `getStressCapacity`)
- **Per-peripheral stream view** with current amount, inflow/outflow, and net rates (per second, minute, hour)
- **Storage forecasting** when max capacity is known (time until full)
- **Inflow lock** to pin production rate when outflow would skew net sampling
- **Organize app** to assign streams → machines → factories
- **Remote push API** via Rednet for custom peripheral scripts

## Installation

1. Copy the entire repository onto a CC:Tweaked computer:
   - `startup.lua` (computer root)
   - `moomdeck/` (folder)
2. Attach peripherals via **wired modems** on a common network.
3. Reboot the computer (or run `startup.lua`).

For the best experience, attach a **monitor** to the computer. MoomDeck auto-detects it and expands the UI.

## Recommended Setup (Cobblestone Generator Example)

1. Place your cobblestone output chest with a wired modem.
2. Connect it to your MoomDeck computer's wired network.
3. Open **Peripherals** in the taskbar — MoomDeck auto-detects the chest inventory and tracks `minecraft:cobblestone`.
4. Open **Organize**:
   - Press `N` to create a factory (e.g. `Stone Works`)
   - Press `M` to create a machine (e.g. `Cobble Gen`)
   - Select the stream and machine, press `A` to assign
5. View aggregated rates in **Dashboard**.

### Optional: Set max storage

In `moomdeck/data.json`, or via a pushed payload, set `max_storage` on a stream to enable fill-time estimates.

## Apps

| App | Description |
|-----|-------------|
| **Dashboard** | Overview by factory, machine, or all streams |
| **Peripherals** | Live readings grouped under each connected device |
| **Organize** | Create factories/machines and assign streams |
| **Settings** | Rescan peripherals, view config |

## Controls

| Key / Action | Context |
|--------------|---------|
| Taskbar click | Switch apps |
| Mouse scroll | Scroll lists |
| `L` | Toggle inflow lock on selected stream (Peripherals app) |
| `S` | Set max storage on selected stream (Peripherals app) |
| `N` | New factory (Organize) |
| `M` | New machine (Organize) |
| `A` | Assign selected stream to selected machine |
| `C` | Clear stream assignment |
| `R` | Rescan peripherals (Settings) |
| `Q` | Quit MoomDeck (Settings) |

## Resource Categories

| Category | Unit | Typical Sources |
|----------|------|-----------------|
| `item` | items | Chests, drawers, belts (via target block) |
| `fluid` | mB | Tanks, fluid handlers |
| `energy` | FE | Energy cells, energy detectors |
| `stress` | SU | Create stressometer, CC:C Bridge target |

## Inflow / Outflow Logic

MoomDeck uses multiple strategies depending on what the peripheral exposes:

1. **Direct flow** — Advanced Peripherals `energy_detector.getTransferRate()` reports true throughput.
2. **Gross delta splitting** — When only storage level is available, positive deltas accrue as inflow and negative as outflow over a rolling window.
3. **Inflow lock** — Press `L` on a stream in the Peripherals app to pin the displayed production rate. Outflow is then derived from locked inflow minus net storage change.

## Remote Push API

Run `examples/peripheral_push.lua` on a satellite computer to push readings over Rednet:

```lua
rednet.send(MAIN_ID, {
    type = "moomdeck_push",
    peripheral = "cobble_gen_scanner",
    key = "item:minecraft:cobblestone",
    category = "item",
    resource = "minecraft:cobblestone",
    label = "Cobblestone Generator",
    current = 640,
    max_storage = 1728,
    flow_in = 2.5,   -- optional direct inflow rate
    flow_out = 1.0,  -- optional direct outflow rate
})
```

## Data Persistence

Configuration and taxonomy are stored in `moomdeck/data.json` on the computer disk.

## Mod Dependencies

- **Required:** CC:Tweaked
- **Optional:** CC:C Bridge, Advanced Peripherals, Create

Generic CC:Tweaked peripheral types work without addon mods. Addon-specific adapters activate automatically when those peripheral types are detected.

## File Layout

```
startup.lua
moomdeck/
  boot.lua
  config.lua
  apps.lua
  core/
  services/
  adapters/
  ui/
examples/
  peripheral_push.lua
```

## License

MIT — use freely in your Minecraft worlds and modpacks.
