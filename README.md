# ISO11146 Laser Beam Analyzer

![](!docs/img/0_splash.png?raw=true)

## Overview
- This code can be used for ISO11146 analysis of stigmatic and simple astigmatic lasers.
- This code was developed to be used with a [proprietary system][refFokPok] developed at [IFSW University of Stuttgart][ifsw] for online analysis.
- However, most of the code can be used offline script-based or via the GUI if a series of beam profiles are provided.
  - The latter is a scenario often encountered at the IFSW, as most processing stations are equipped with axis systems and appropriate camera systems.

- All you need to do is record images of your beam profiles along the caustic using your camera system. If you use additional optical elements and filters ensure they don't introduce ghosting and/or aberrations.
- (Make sure to record enough near- and far-field images for a robust fit of the caustic hyperbola.)
- (Note: Background subtraction using a dark image/video is *risky* without specific knowledge of the behaviour of your camera system and setup. Pre-process your images this way if you are certain you are not compromising the data.)

## How do I use this?
- **Without Installation, MATLAB >= 2021a**
  - Simply start the GUI via [startGUI.m](startGUI.m).
  - If you enable some of the debugging features the image processing toolbox is required.
  - It is recommended to experiment with the GUI and [test datasets](/TestData) first.
  - For custom data input analyze your data via script: [analyze_example.m](analyze_example.m).

- **Using the installer**
  - Install the application using the [installer](/binaries/IFSW_BeamAnalyzer_standalone/for_redistribution).
  - The binaries require the R2021a (9.10) runtime. The installer will download the required dependencies. A full installation of MATLAB is not required.

## Workflow using GUI and single images
- Start the GUI/App.

![](!docs/img/1_main.PNG?raw=true)

- Load and tag your images / specify pixelpitch and wavelength.
- It is attempted to extract the z-position from the filename. Reproduce the naming scheme of the [test datasets](/TestData) for your data to use this feature.

![](!docs/img/2_selector.png?raw=true)

- Adjust analysis / plot settings if required.

![](!docs/img/3_settings_overview.png?raw=true)

- Review / export plots. Some plots are interactive.

![](!docs/img/4_results_pp.png?raw=true)

- And export the data to .xlsx / .mat.

![](!docs/img/5_results_overview.png?raw=true)

## Additional materials / Youtube (German, English subtitles!)

<a href="http://www.youtube.com/watch?feature=player_embedded&v=PEa2JmkxwxU
" target="_blank"><img src="http://img.youtube.com/vi/PEa2JmkxwxU/0.jpg" 
alt="Presentation (German)" width="240" height="180" border="10" /></a>

## Disclaimer

- Code is provided "as is".
- [Please forward bugs, errors and suggestions via mail.](mailto:david.brinkmeier@ifsw.uni-stuttgart.de)

[ifsw]: <https://www.ifsw.uni-stuttgart.de/en/>
[refFokPok]: <https://doi.org/10.1117/12.2079037>
