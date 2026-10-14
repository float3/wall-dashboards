# wall-dashboards

Full-screen panels for a display across the room: indoor air quality, weather,
and the next departures from your stops. one small Rust service serves them
all, polls upstream on its own schedule, and keeps working when upstream does
not.

it exists because the alternative is pointing a kiosk browser at somebody's
website, and websites log you out, move things around, show cookie dialogs and
ads, and are laid out for a desk rather than a wall.

## panels

every panel is optional. a host configures the ones it wants, and the rest are
neither polled nor served.

| Route | Source | Shows |
| --- | --- | --- |
| `/air` | An [AirGradient](https://www.airgradient.com/) monitor on your LAN | PM1/PM2.5/PM10, CO₂, TVOC, NOx, temperature and humidity over three hours, with an alarm |
| `/weather` | [Open-Meteo](https://open-meteo.com/) (no key) | Now, a daylight arc, a 24 h rain timeline, three days in detail and ten in outline |
| `/transit` | MVG's departures endpoint | Realtime departures per stop, with delays and cancellations |

`/` lists whichever are configured.

the polling happens in the service, not the page. a wall display usually
rotates through several pages, so any one panel is on screen a fraction of the
time; polling here means the air panel has a full history behind it the moment
it appears, and upstream is asked once however many browsers are looking.

## the air alarm

each measure can be given a safe range. three readings outside it raise the
alarm and three inside it clear the alarm, so one spike stays quiet. the chart
gets a red outline, the header says which measure and which way, and the
service can make a noise or run a hook.

a sensor that has stopped answering raises the alarm too. without that, a
frozen chart looks exactly like clean air.

silence the sound without hiding the charts:

```sh
curl -X POST 'http://127.0.0.1:8123/air/mute?minutes=30'
curl -X POST http://127.0.0.1:8123/air/unmute
```

### getting the alarm to somebody

two hooks, neither assuming a sound card:

- `air.alarm.device` writes `EV_SND` tones to an evdev node, normally the PC
  speaker.
- `air.alarm.command` runs a shell line whenever the set of alarms *changes*,
  with `ALARM_STATE`, `ALARM_MEASURES` and `ALARM_TEXT` in the environment. it
  fires on transitions only and never on the repeat, so a push
  notification is sent once per alarm rather than once per reading.

anything needing the machine's sound hardware belongs in a user service polling
`/air/data`: this one runs as a `DynamicUser` with no seat and no access to
anyone's audio session.

**do not assume the PC speaker works.** a machine that beeps at power-on often
cannot be made to beep from Linux: on many small-form-factor boards the POST
beep comes from the embedded controller and the PIT speaker line drives
nothing. the driver will accept your tones and report success while making no
sound at all. a BIOS pin config claiming an internal speaker proves nothing
either — the part is often simply not fitted. test with a long continuous tone
before you rely on any of it.

## configure it

```nix
{
  inputs.wall-dashboards.url = "github:float3/wall-dashboards";

  # in your host's modules:
  imports = [inputs.wall-dashboards.nixosModules.default];

  services.wall-dashboards = {
    enable = true;
    air = {
      enable = true;
      sensorUrl = "http://10.0.0.5";
      limits.rco2.max = 1000;
    };
    weather = {
      enable = true;
      latitude = 52.52;
      longitude = 13.41;
    };
    transit = {
      enable = true;
      stops = [
        {
          globalId = "de:09162:2"; # Marienplatz
          name = "Marienplatz";
          walkMinutes = 3;
        }
      ];
    };
  };
}
```

find a stop's id with:

```sh
curl 'https://www.mvg.de/api/bgw-pt/v3/locations?query=<name>'
```

every option is documented in [`module.nix`](module.nix). without flakes it is
an ordinary NixOS module, and `package.nix` an ordinary `callPackage` file.

### your location is not in this repository

coordinates, stop ids and the address of a sensor on your LAN say where you
live. none of them are in this repository, and none of them have defaults here:
they are required options, written by whoever deploys it, into a config file
this service reads at startup. keep that config in a private repository.

## notes on the air numbers

- **an AirGradient ONE has no oxygen sensor.** CO₂ is the only stand-in for a
  room going stuffy, which is why it carries the default range it does.
- **PM readings of exactly 0 are usually real.** the PMS5003 quantises mass to
  1 µg/m³ and averages a handful of samples, so in clean indoor air PM1 and
  PM10 sit at 0 and only the particle counts still move.
- **PM2.5 jumps between 0 and about 1.6.** the panel plots `pm02Compensated`,
  the humidity-corrected value, as AirGradient's own dashboard does. the
  firmware special-cases a raw 0 to 0 but maps a raw 1 to roughly 1.6, so the
  compensated trace has a gap it can never land in. it looks like noise and is
  not.

## run it by hand

```sh
cargo run --release -- config.json
```

then open <http://127.0.0.1:8123>. the config file is the only input; the
NixOS module is a typed front end that writes one.

the pages are baked into the binary, so the service is a single artifact with
nothing beside it to install. each page is plain HTML with hand-drawn SVG and
no libraries.

## adding a panel

a route in `src/main.rs`, a file in `pages/`, and a poller — `src/feed.rs` has
a cached one for anything that is just somebody else's JSON, which is most
things. `src/air.rs` is the shape to copy when a panel needs to keep history
or judge what it sees.
