# Beamfit

![](docs/logo.png?raw=true "beamfit")

## Offline and Online analysis for laser beams
  - Least square elliptical rotated Gaussian fit (D4σ specification), cf. [docs](docs/).
  - Least square trepanning (rotating on a circular path) symmetrical Gaussian fit (D4σ specification).
  - Second-order moments / ISO11146 beam width for elliptic beams (D4σ specification).
    - Based on this [implementation][imagemoments] by Raphaël Candelier with minor adjustments to fit the ISO11146 spec.

- **Offline analysis supports image and video processing**
  - Examples and results for usage with [example_general_purpose.m](example_general_purpose.m) are provided in the [examples](examples/).
  - [example_synthetic.m](example_synthetic.m) allows for generation and analysis of noisy rotated offset elliptical Gaussians as well as noisy trepanning offset symmetrical Gaussians for testing purposes.
- **Online analysis supports IDS uEye cameras through uEyeDotNet.dll**
  - [example_online_ueye.m](example_online_ueye.m) allows for online usage with uEye cameras. Make sure that the location of the *uEyeDotNet.dll* in the header is correct.
  - Specification of uEye cameras (Pixel pitch etc.) are auto-detected. Check out the uEye [example](examples/ueye/) to see what it looks like with a beam incident on a diffuser and reimaged onto the sensor, which required heavy post-processing to get a useful online reading for the center of gravity due to speckles.
  - Minor bugfixes were applied to the [uEye-dotnet Matlab library][ueye_lib] from [Dr. Adam Wyatt][adamwyatt].
  
## Image processing
  - Built-in functionality includes various DC-offset removal / noise removal techniques including 
  [noisecomp][kovesi] from Peter Kovesi and [TV-L1 denoising][tvl1] from Manolis Lourakis.
  - Automated and/or GUI-cropping / pre-scaling of input for faster fitting etc.
  - Why image cleanup? Second-order moment determination of beam diameter/radius is particularly prone to measurement noise.
    - Warning: Due to the definition of beam diameter through the second order moments this means it's also possible to effectively falsify the ISO11146 measurement through usage of excessive denoising.
  - Additionally / alternatively an offset background image which is subtracted from the input may be provided.

## Features
- Horrible mess of procedural code, held in place by duct-tape.
  If I were to do it today, I would do it properly and most likely in Python.
- That being said, the code works and has proven to be useful in practice. Especially when compared to many proprietary / expensive beam measurement software/hardware bundles.
- Usage is intended with Camera sensors WITHOUT lens. If you have an imaging system, you need to take the specification of your imaging setup into account.
If this means nothing to you, a commercial system may be better suited for your purposes.

## Disclaimer

- As stated in the license...code provided "as is". If you need certified measurements, use certified measurement hardware and software!

[imagemoments]: <http://raphael.candelier.fr/?blog=Image%20Moments>
[kovesi]: <https://www.peterkovesi.com/matlabfns/>
[tvl1]: <https://de.mathworks.com/matlabcentral/fileexchange/57604-tv-l1-image-denoising-algorithm/>
[ueye_lib]: <http://matlabtidbits.blogspot.com/2016/12/ueye-camera-interface-in-matlab-net.html>
[adamwyatt]: <https://www.clf.stfc.ac.uk/Pages/Adam-Wyatt.aspx>
