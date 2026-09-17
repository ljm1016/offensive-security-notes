#osint

## Document metadata
```bash
apt install libimage-exiftool-perl
exiftool -Author -Creator -Producer *.pdf
```
```
Author    : jsmith                # recorded author value
Creator   : Microsoft Word 2016   # software and version
Producer  : Acrobat Distiller 11.0
```
Fields vary by file and can be removed or edited — treat them as a lead (an account name, an internal path, a software version), never as proof of current ownership, access, or a vulnerable version.

## Image metadata
Same idea, image-specific fields:
```
Model             COOLPIX P6000
DateTimeOriginal  2008:10:22 16:28:39
GPSLatitude       43° 28' 2.814" N
GPSLongitude      11° 53' 6.456" E
```
Metadata can be edited — a GPS tag alone doesn't prove place or time, it's a lead to corroborate against something independent.

## Reverse image search
- **TinEye** reports *when its crawler first found a copy* — not the image's creation date. No matches means no indexed copy was found, not that the image is unique.
- **Google Lens**, **Yandex Images** — same caveat, different index coverage. Check more than one.

## Geolocation from frame clues
| | Narrows |
| --- | --- |
| Where | Driving side, utility poles, curbs, road marking color, license plates, vegetation, signage → country down to street. [plonkit.net](https://plonkit.net) has a country-by-country guide |
| When | Shadow direction/length (needs a known location) via [suncalc.org](https://suncalc.org); weather records via timeanddate.com/weather; construction progress and vehicles can also bound a date range |

**No single clue is proof.** A plate narrows to a region, a sign to a language area, a mountain profile to a line of sight — combine clues into a candidate, then confirm it against street-level or satellite imagery before recording it as a finding.

See [[Case Studies]] for MH17, McAfee, and the Myanmar satellite cases — all of this in practice, including where it went wrong or needed a second source.
