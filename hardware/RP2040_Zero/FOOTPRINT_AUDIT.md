# RP2040-Zero footprint audit

This revision assigns footprints using the Waveshare product photos/current product page, package datasheets, and the published BOM/footprint table for the closely-related Waveshare RP2040-Tiny design.

## Assigned with high confidence

| Ref(s) | Component | KiCad footprint | Basis |
|---|---|---|---|
| U3 | RP2040 | `Package_DFN_QFN:QFN-56-1EP_7x7mm_P0.4mm_EP3.2x3.2mm` | RP2040 datasheet: QFN-56, 7x7 mm, 0.4 mm pitch, 3.2 mm EP |
| U2 | W25Q16JVUXIQ | `RP2040_Zero_Footprints:W25Q16JVUXIQ_USON-8_2x3mm` | Exact Winbond UX package: USON-8 2x3 mm, 0.5 mm pitch |
| U1 | RT9013-33 / current production ME6217C33M5G | `Package_TO_SOT_SMD:SOT-23-5` | Both regulator variants are SOT-23-5 |
| X1 | 12 MHz crystal | `Crystal:Crystal_SMD_2520-4Pin_2.5x2.0mm` | Waveshare RP2040-Tiny BOM specifies CRYSTAL-SMD_2520; RP2040-Zero rear photo matches 2520 |
| C1-C19 | capacitors | `Capacitor_SMD:C_0201_0603Metric` | Related Waveshare RP2040-Tiny BOM uses C0201 for all these values; Zero photos show the same miniature passives |
| R2-R6,R8,R9 | populated resistors | `Resistor_SMD:R_0201_0603Metric` | Related BOM uses 0201; photo scale agrees |
| R1,R7 | NC/DNP resistors | `Resistor_SMD:R_0402_1005Metric` | Related Waveshare RP2040-Tiny BOM uses R0402 specifically for NC option resistors |

## Assigned from photo/mechanical match; verify before production

| Ref(s) | Footprint | Confidence / caveat |
|---|---|---|
| J1 | `RP2040_Zero_Footprints:USB_C_HRO_TYPE-C-31-M-12_Waveshare` | High-ish: the 12-contact layout, shell tabs, and locating holes match HRO TYPE-C-31-M-12 geometry in KiCad. Exact connector manufacturer is not published by Waveshare. |
| Key1, Key2 | `RP2040_Zero_Footprints:SW_Tactile_4.5x4.5mm_PhotoMatched` | Medium: body size and four-terminal geometry are inferred from high-resolution photos. Exact switch MPN is not published, so the land pattern should be measured on a real board/part before manufacturing a clone. |

## Intentionally left without a component footprint

`L1` (addressable RGB LED) is intentionally left unassigned. The package is visibly the 2.0 x 2.0 mm / 0807 class and the related Waveshare BOM calls it `0807 RGB`, but published WS2812B-2020 pinouts use a different pad numbering from the source Waveshare schematic/local symbol. Assigning a standard WS2812B-2020 footprint without verifying the actual fitted LED could silently swap power/data pins. Verify the real LED MPN or continuity on a physical RP2040-Zero before assigning its pad map.

`P1`, `P2`, and `P3` represent the RP2040-Zero PCB's castellated/perimeter and underside solder pads, not purchasable header components. Assigning generic pin-header footprints would be wrong. They should be replaced by custom board-pad geometry when reconstructing the PCB layout. Waveshare publishes the module outline (18.00 x 23.50 mm, 2.54 mm edge-pad pitch) and a STEP model, which can be used for that next step.

## Revision note

The source schematic PDF names U1 as `RT9013-33`, while the current Waveshare product page labels the production regulator `ME6217C33M5G`. Both use SOT-23-5, so the footprint assignment remains valid without changing the source schematic's electrical circuit.

## Web references

- Waveshare RP2040-Zero product page: https://www.waveshare.com/rp2040-zero.htm
- Waveshare RP2040-Zero wiki: https://www.waveshare.com/wiki/RP2040-Zero
- Waveshare RP2040-Tiny schematic/BOM: https://files.waveshare.com/upload/7/7a/RP2040-Tiny_Schematic.pdf
- Winbond W25Q16JV datasheet (package code UX): https://cdn-learn.adafruit.com/assets/assets/000/116/709/original/datasheetQspi.pdf
- Raspberry Pi RP2040 datasheet: https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
- KiCad HRO TYPE-C-31-M-12 footprint geometry: https://github.com/KiCad/kicad-footprints/blob/master/Connector_USB.pretty/USB_C_Receptacle_HRO_TYPE-C-31-M-12.kicad_mod

- WorldSemi WS2812B-2020 datasheet: verify pin numbering against the fitted part before assigning L1.
