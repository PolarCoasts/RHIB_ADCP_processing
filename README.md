# RHIB_ADCP_processing

## Description
This package is designed to handle ADCP processing in the field. It is customized for the current (2023) configuration of components installed on the OSU RHIB fleet. RHIBproc is the main script that manages all of the processing steps. Details for current fieldwork can be entered at the top of the script. It searches the current folder (and subfolders) for data files collected from the RHIBs, parses data from those files, transforms the velocity data into Earth coordinates, removes RHIB velocity based on gps data, saves the processed data, and plots and saves a few basic figures. The parsing of data and processing of the velocity data are packaged in modular form so that those components can be run independently from the command line. This package handles the basic processing of data, but applies no smoothing or quality control. At this point, it can only handle data from RDI ADCPs.


## Requirements
- MATLAB R2019b or later (use R2022b or later for best mapping of LeConte Bay)
- Mapping Toolbox
- Navigation Toolbox
- m_map package (https://www.eoas.ubc.ca/~rich/map.html)
- cmocean (https://www.mathworks.com/matlabcentral/fileexchange/57773-cmocean-perceptually-uniform-colormaps)


## Quick start guide
In most cases, RHIBproc will provide a quick and easy way to process data in the field. As long as the working directory contains the raw data files with the expected file structure, the script can be run without modification. It will prompt the user to confirm the list of instruments and offset angles. if they are correct, enter y. If not, enter n and they can be modified at the top of RHIBproc under "CUSTOMIZE PROCESSING DETAILS HERE". The script will complete the processing for all RHIB deployments in the directory, save processed data, and plot and save a few figures. For an explanation of other processing details that can be customized, see "How to use RHIB_ADCP_processing" below. If you experience problems in the field, see "Troubleshooting".

## Contents of package
The package contains the following functions and scripts:
- **RHIBproc**:  top level script that manages file structure, parsing of raw data, processing of velocities, saving processed data, plotting and saving figures
    - **ParseDeployment**: manages the parsing of data from IMU, GPS, and ADCP - **can be run independently**
        - **parse_imu**: parses data from IMU
        - **parse_rdi_adcp**: parses data from and RDI ADCP
        - **parse_gps**: parses data from GPS
    - **ProcADCP**: manages the processing of ADCP data - **can be run independently**
        - **nucRepair**: deals with occasional anomalies in timestamps from the RHIB computer
        - **compute_vessel_vel**: computes the RHIB velocity based on the method input in RHIBproc
        - **gps_ltln2vel**: computes the RHIB velocity if vessel_vel_method='GPRMC distance/time'
        - **gps_line_interp**: matches GPS heading entries with GPS time
        - **adcp_beam2earth**: transforms velocities from beam coordinates to Earth coordinates
    - **ClipAirTime**: identifies data collected while RHIB is out of water (based on low correlation and echo intensity) and clips it from the record - **can be run independently**
    - **PlotTrack**: plots the GPS track for the given deployment and colors it by time, if data is collected in/around LeConte Bay it also inserts a map of the bay showing where the data was collected - **can be run independently**
    - **PlotBeams**: plots raw beam data, user can select beam velocity, correlation, or echo intensity - **can be run independently**
    - **PlotENU**: plots rotated velocities and error velocity - **can be run independently**

- **LoadDeployment**: this function is provided for user convenience, it is not used by RHIBproc. It displays a list of processed files in the current directory and the user enters the line number of the desired file to load the data. 


## How to use RHIB_ADCP_processing
### Utilizing RHIBproc
RHIBproc is the top level script that manages everything. It expects to be in a directory that contains a folder named 'raw/'. Within 'raw/', it expects to find folders named for each RHIB (Aires, Polly, etc.) and within that, the deployment file. The complete file path should be: raw/rhibname/deployment#/...

Depending on the ADCP installation and deployment details, there are a few options that need to be defined near the top of RHIBproc under the section titled "CUSTOMIZE PROCESSING DETAILS HERE".
- parse_nuc_timestamps
    - set to true to use the RHIBs computer time (which should be synced to the GPS clock) as timestamped for each ADCP ping instead of the ADCP clock  
- vessel_vel_method
    - set to 'GPRMC groundspeed and course' to calculate the RHIB velocity from GPS-derived speed and course logged in the GPRMC sentences (this seems like the best option, but you may want to experiment)
    - set to 'GPRMC distance/time' to calculate the RHIB velocity from the change in GPS-derived location over time
    - other options are coded, which may or may not be functional
- beam5_weight
    - this is used when transforming velocities from the Sentinel V. It describes the weighting given to the vertical beam in determining vertical velocity. A value of 0 results in all velocities being calculated just as a 4-beam ADCP. A value of 1 imposes the vertical velocity observed by beam 5 as the vertical component of velocity in the calculation of the horizontal velocities. Any value between 0 and 1 may be used.
- overwrite
    - set to false to only process files for which a processed file does not exist
    - set to true to process all files, overwriting any existing processed files
- clipAir
    - set to true to automatically trim the portion of the record collected while the RHIB was out of the water
    - The function that does this seems to be working pretty well, but has not been extensively tested. There are some thresholds that can be adjusted or this step can be skipped by setting clipAir=false.
- serial and offset
    - to deal with potential inconsistencies with the installation of the ADCP in the RHIB, you can define the angle of offset for a particular ADCP by identifying the instrument serial number and its offset
    - for 2022/2023, the two ADCPs being used are a Sentinel V (serial #24653) and a Workhorse (serial #14185)

When the above settings are entered as desired, the script just needs to be run. It will prompt you to confirm the serial #s and offsets, then run through the processing of all files in the current directory, save the processed file, and create and save plots of the GPS track, beam velocities, correlation, echo intensity, and rotated velocities. The script can be run every time a new deployment is added to the directory or after several deployments have been added. As long as overwrite=false, it will only process the new files. 

### Parsing and processing data independent of RHIBproc
If conditions in the field differ from those expected, RHIBproc may not be the most efficient way to handle the data. This may occur if the file structure desired for storing the processed data changes from one deployment to the next or if ADCPs are being moved back and forth between RHIBs so that the offset angle is not always the same. If this is the case, the data parsing and data processing modules can be run independently.

To parse the data from the raw files:

	datastruct = ParseDeployment(filepath,true);
	
This will return a structure with substructures for the raw ADCP, IMU, and GPS data (note that IMU data is not used in the actual processing, so will not be retained).


To transform the velocities to Earth coordinates and remove the RHIB velocity:

	adcp = ProcADCP(datastruct,yaw_offset,'GPRMC groundspeed and course',1);
	
This will return a structure with the processed ADCP data as well as location and RHIB velocity from the GPS data.

You may choose to automatically clip the leading/trailing portions of the record collected while the RHIB was in the air. 

	adcp = ClipAirTime(adcp);

The processed data will then need to be saved manually. All of the included plotting functions may be run independently:

	[fig,ax] = PlotTrack(adcp);
	
	[fig,ax] = PlotBeams(adcp,'corr');
	
	[fig,ax] = PlotENU(adcp);
	
Alternatively, PlotBeams can be run with second positional argument of 'bvel' or 'echo'. When called directly, figures will need to be saved manually as well.

### Loading processed data
LoadDeployment provides a convenient way to look up filenames and load processed data. 

	adcp = LoadDeployment;
	
This will display a numbered list of all processed files contained in the working directory (and subdirectories). Enter the line number of the desired file and the data is loaded into the adcp structure.


## Troubleshooting
This section provides some workarounds in the event that it is discovered in the field that some requirements are missing

| Problem								| Workaround															|
| :---									| :------------															|
| using MATLAB release prior to R2019b		| Unfortunately there is no easy solution to this. Many of the functions are built with argument blocks. Those would need to be removed and defaults, validations, and optional inputs would need to be handled another way	|
| missing Mapping/Navigation toolboxes		| In RHIBproc, comment out lines 107-109. This will skip plotting of the GPS track		|
| missing m_map						| in ProcADCP, comment out lines 31 & 32. This will omit translating lat/lon to UTM x/y	|
| missing cmocean						| In PlotBeams line 20 and PlotENU line 32, replace colormap						| 



## Future developments
- Nortek processing
- Clean up compute_vessel_vel
- Handling of timestamped GPS data files


## Credits
The RHIB_ADCP_processing package is based heavily on the ROSE_code package developed by Dylan Winters. Many of the low level functions are nearly exactly as he wrote them. The current package represents an overhaul of the code framework by Bridget Ovall to update, simplify, consolidate, and debug the package. 


