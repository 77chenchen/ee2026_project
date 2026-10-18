# EE2026 FPGA Design Project (FDP) Manual

> Markdown transcription and implementation checklist based on
> `EE2026 - Project Manual.pdf` (15 pages, dated 27 September 2026).
> The PDF remains the authoritative document if any wording differs.

## 1. Project overview

- Course: EE2026 Digital Design, AY 2026-27 Semester 1.
- Platform: Basys3 FPGA and one Pmod OLED per member. The OLED has a 96 x 64,
  16-bit RGB565 display.
- Build one **interactive FPGA design project (I-FDP)** in Verilog. The project
  must run as **one bitstream**. Separate bitstreams for individual components
  are not accepted for the final assessment.
- The default theme is an FPGA-based smart graphical calculator. Groups may
  choose another theme, but all individual components must be strongly related
  and integrate into one coherent system.
- Discussing ideas is allowed; copying code or reports is not. Each member is
  accountable for both individual and group work.

## 2. Marking and schedule

| Period | Deliverable | Weight | Notes |
| --- | --- | ---: | --- |
| Weeks 7-8 | (U)GPT-5 OLED familiarisation | Ungraded | Practice tasks; no submission required. |
| Weeks 8-9 | GPT-6 project proposal | 2% group | One PDF, uploaded to Canvas. |
| Weeks 9-12 | Individual components A-D | 9% each | Demonstrated as part of the one integrated bitstream. |
| Weeks 9-12 | Full integration | 9% group | Components must form one complete product. |
| Weeks 12-13 | Peer feedback | 1% individual | Canvas task. |
| Weeks 12-13 | Demo, report, Q&A and execution | 9% individual | Assessed during presentation and from report/feedback. |

### Important dates

- **GPT-6 deadline: Monday 19 October 2026, 06:00.**
- Final project archive, report and peer-feedback dates are announced on Canvas
  after the Theory Quiz 2 date is finalised. Deadlines cannot be extended.
- The final demonstration should be 2-5 minutes for the team, excluding Q&A.
  It must reach every claimed feature quickly; assessors may skip features that
  require lengthy setup.

## 3. Required calculator capabilities

The default graphical-calculator project must satisfy all of the following.

| Area | Compulsory requirement | Useful enhancement examples |
| --- | --- | --- |
| Functionality | Add and subtract whole numbers, including a single-digit expression such as `8 + 5`. | Multiply/divide, decimal points, alternate number representations, trigonometry, graphing, conversions, education features. |
| Reliability | No reprogramming for each calculation; system should not regularly crash on unexpected input. | Reset, reliable feature switching, multi-board communication. |
| Interface | Use switches, LEDs and OLED. | Seven-segment display, mouse, keyboard, more OLEDs. Avoid unnecessary devices. |
| Experience | Values are easy to enter and results easy to see on the Basys3. | Intuitive interface, on-board guidance, modes/brightness, engaging interaction. |

Enhancements should be strongly tied to the calculator theme. A deeply integrated
graphing enhancement is more valuable than several unrelated small features.
Resource-efficient design is expected; avoid expensive arithmetic or rendering
approaches when they are not needed.

## 4. Hardware and resource rules

- Basys3 and OLED are compulsory. Mouse, keyboard and lab-provided audio/HDMI
  devices are optional; no additional marks are awarded merely for using them.
- Do not use unapproved external devices. Connecting two Basys3 boards requires
  written approval plus an exact wiring schematic.
- Do not place two OLEDs on the same side of a Basys3; they physically interfere.
- Do not touch the OLED ribbon cable while inserting/removing it; power the board
  off before connecting it. No deadline extension is given for damaged equipment.
- Monitor `Project Summary -> Utilization -> Post-Implementation`; the design
  must fit the Basys3 FPGA. Integrate early and often because utilisation can
  increase sharply during integration.

## 5. Template modules and OLED interface

The Canvas template includes these files:

- `My_Top_Module.v`: your top level; modify it and instantiate your modules.
- `Oled_Display.v`: OLED SPI/display interface. It normally needs no changes.
- `MouseCtl.vhd` and `Ps2Interface.vhd`: optional wired-mouse interface.
- `Basys3_Master.xdc`: I/O constraints; enable only the ports that are used.

### OLED integration checklist

1. Create a 6.25 MHz `clk6p25m` signal for `Oled_Display`.
2. Drive a 16-bit RGB565 `pixel_data` value (for example, green is `16'h07E0`).
3. Use `pixel_index` (0 to 6143) to identify the pixel being drawn.
4. Derive coordinates with `x = pixel_index % 96` and `y = pixel_index / 96`.
5. Connect the OLED pins to the Pmod connector in the constraints file.
6. Generate and test a bitstream on the real board. A basic test is green
   background with `sw[4]=0`, red background with `sw[4]=1`.

`Oled_Display` supplies frame/pixel timing signals and serial output pins; do
not implement another OLED SPI driver unless there is a compelling reason.

## 6. (U)GPT-5 OLED practice requirements

These practice tasks are ungraded but prepare the group for the final project.
All button behaviour must detect a short press within 200 ms, debounce it, and
count a long hold as one press.

| Task | Required behaviour |
| --- | --- |
| 1 | Draw two large student-number characters and a white filled circle. `BTNU` toggles the drawings on/off. Digits: at least 45 px high, 25 px wide, 6 px strokes. |
| 2 | Draw a green 20 x 20 square and two small coloured digits. Each `BTND` cycles the square: green -> red -> blue -> yellow -> green. |
| 3 | Draw two digits. With `SW1=1`, the blue digit moves smoothly between edges in about 3 +/- 0.5 seconds; with `SW1=0`, it pauses and later resumes in the same direction. |
| 4 | Integrate Tasks 1-3 in one bitstream; display group ID on seven-segment displays. Select OLED content with `SW15/SW14/SW13`: `001` Task 1, `01X` Task 2, `1XX` Task 3. |

## 7. GPT-6 proposal submission

Submit **one PDF per group** to Canvas in week 9, named `GPT6_SX_YZ` (replace
with the official group ID). The proposal is no more than two pages (one sheet).

### Required content

- Group ID and a 100-200 word group-theme description (minimum 100 words).
- For every member: name, one major distinct responsibility, and a week 7-12
  plan. The member section should be 100-300 words (minimum 100 words).
- Weeks 7-9 must describe distinct completed/planned tasks; weeks 10-12 must
  clearly define the remaining work.

The 2% GPT-6 mark is split equally between meaningful week 7-9 descriptions and
clear week 10-12 descriptions. Implementation may change after the proposal;
there is no need to submit an updated proposal.

## 8. Final Canvas submission

### Item A - project archive

- One Vivado project archive per team, maximum 500 MB unless prior approval is
  obtained.
- Before archiving, successfully generate and test the one final bitstream on a
  Basys3.
- After upload, download and unzip the archive to verify the project still opens
  and builds correctly.

### Item B - report PDF

- **Sheet A (pages 1-2):** group theme plus one component section for each
  member. A four-person team has a 500-word combined maximum across its five
  sections (400 words for three members, 300 for two).
- Describe only features that are working and demonstrated in the single final
  bitstream. Undemonstrated claims and demonstrated-but-undescribed features are
  penalised/not awarded respectively.
- Include clear colour photos of the real OLED/board, not computer simulations.
  Highlight the team section light pink; students A-D light red, blue, yellow,
  and green respectively.
- **Sheet B (pages 3-4):** course feedback and references only.
- Cite every open-source code source and clearly document any use of AI/code
  generators/chatbots; extra pages are allowed for that documentation.
- Bring two printed colour copies to the assessment.

### Item C - peer feedback

Complete the Canvas peer-feedback activity in the announced week 12/13 window.

## 9. Project-specific acceptance checklist

Before declaring the graphical calculator ready, verify on physical hardware:

- [ ] The single integrated top module builds, meets timing, and produces a
  tested bitstream.
- [ ] OLED, switches and LEDs are all visibly used.
- [ ] A user can complete at least one addition and one subtraction without
  reprogramming the FPGA.
- [ ] Reset/back/mode transitions and malformed inputs do not lock up the UI.
- [ ] Button presses are debounced and a held button generates one action.
- [ ] Every member's component is reachable in the final user flow and can be
  demonstrated in under five minutes.
- [ ] FPGA utilisation and timing are checked after integration.
- [ ] The report matches the final bitstream exactly and documents all external
  code/AI usage.

