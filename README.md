# ISO11146 Laser Beam Analyzer

![](!docs/img/0_splash.png?raw=true "splash")

## Overview
- This code can be used for ISO11146 analysis of stigmatic and simple astigmatic lasers.
- This code was developed to be used with a [proprietary system][refFokPok] developed at [IFSW University of Stuttgart][ifsw] for online analysis.
- However, most of the code can be used offline script-based or via the GUI if a series of beam profiles are provided.
  - The latter is a scenario often encountered at the IFSW, as most processing stations are equipped with axis systems and appropriate camera systems.

- All you need to do is record images of your beam profiles along the caustic using your camera system.
- (Make sure to record enough near- and far-field images for a robust fit of the caustic hyperbola.)
- (Note: Background subtraction using a dark image/video is *risky* without specific knowledge of the behaviour of your camera system and setup. Pre-process your images this way if you are certain you are not compromising the data.)

- **Offline analysis supports image and video processing**
  - Examples and results for usage with [example_general_purpose.m](example_general_purpose.m) are provided in the [examples](examples/).
  - [example_synthetic.m](example_synthetic.m) allows for generation and analysis of noisy rotated offset elliptical Gaussians as well as noisy trepanning offset symmetrical Gaussians for testing purposes.
- **Online analysis supports IDS uEye cameras through uEyeDotNet.dll**
  - [example_online_ueye.m](example_online_ueye.m) allows for online usage with uEye cameras. Make sure that the location of the *uEyeDotNet.dll* in the header is correct.
  - Specification of uEye cameras (Pixel pitch etc.) are auto-detected. Check out the uEye [example](examples/ueye/) to see what it looks like with a beam incident on a diffuser and reimaged onto the sensor, which required heavy post-processing to get a useful online reading for the center of gravity due to speckles.
  - Minor bugfixes were applied to the [uEye-dotnet Matlab library][ueye_lib] from [Dr. Adam Wyatt][adamwyatt].
  
## What do I need?
  - Built-in functionality includes various DC-offset removal / noise removal techniques including 
  [noisecomp][kovesi] from Peter Kovesi and [TV-L1 denoising][tvl1] from Manolis Lourakis.
  - Automated and/or GUI-cropping / pre-scaling of input for faster fitting etc.
  - Why image cleanup? Second-order moment determination of beam diameter/radius is particularly prone to measurement noise.
    - Warning: Due to the definition of beam diameter through the second order moments this means it's also possible to effectively falsify the ISO11146 measurement through usage of excessive denoising.
  - Additionally / alternatively an offset background image which is subtracted from the input may be provided.

## Workflow
- test

## Additional materials / Youtube (German)

<a href="http://www.youtube.com/watch?feature=player_embedded&v=PEa2JmkxwxU
" target="_blank"><img src="http://img.youtube.com/vi/PEa2JmkxwxU/0.jpg" 
alt="Presentation (German)" width="240" height="180" border="10" /></a>

## Disclaimer

- Code is provided "as is".
- [Please forward errors and suggestions to me via mail.](mailto:david.brinkmeier@ifsw.uni-stuttgart.de?subject=[GitHub]%20Source%20Han%20Sans)

[ifsw]: <https://www.ifsw.uni-stuttgart.de/en/>
[refFokPok]: <https://doi.org/10.1117/12.2079037>
[imagemoments]: <http://raphael.candelier.fr/?blog=Image%20Moments>
[kovesi]: <https://www.peterkovesi.com/matlabfns/>
[tvl1]: <https://de.mathworks.com/matlabcentral/fileexchange/57604-tv-l1-image-denoising-algorithm/>
[ueye_lib]: <http://matlabtidbits.blogspot.com/2016/12/ueye-camera-interface-in-matlab-net.html>
[adamwyatt]: <https://www.clf.stfc.ac.uk/Pages/Adam-Wyatt.aspx>
