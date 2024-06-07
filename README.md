# RHIB_ADCP_processing

## Description
This package is designed to handle ADCP processing in the field. It is customized for the current (2024) configuration of components installed on the OSU RHIB fleet. RHIBproc is the main script that manages all of the processing steps and the resulting file structures. Details for current fieldwork can be entered at the top of the script. It searches the current or designated directory (and subfolders) for data files collected from the RHIBs, parses data from those files, transforms the velocity data into Earth coordinates, removes RHIB velocity based on gps data, saves the processed data, and plots and saves a few basic figures. The parsing of data and processing of the velocity data are packaged in modular form so that those components can be run independently from the command line. This package handles the basic processing of data, but applies no smoothing or quality control. At this point, it can only handle data from RDI ADCPs. Some additional functions or options are included for post-processing.


## Requirements
- MATLAB R2019b or later (use R2022b or later for best mapping of LeConte Bay)
- Mapping Toolbox
- Navigation Toolbox
- m_map package (https://www.eoas.ubc.ca/~rich/map.html)
- cmocean (https://www.mathworks.com/matlabcentral/fileexchange/57773-cmocean-perceptually-uniform-colormaps)


## Quick start guide
In most cases, RHIBproc will provide a quick and easy way to process data in the field. As long as the working directory contains the raw data files with the expected file structure, the script can be run without modification. Pointing the code to a different directory can be done with a simple declaration. It will prompt the user to confirm the list of instruments and offset angles. If they are correct, enter y. If not, enter n and they can be modified at the top of RHIBproc under "CUSTOMIZE PROCESSING DETAILS HERE". The script will complete the processing for all RHIB deployments in the directory, save processed data, and plot and save a few figures. For an explanation of other processing details that can be customized, see "How to use RHIB_ADCP_processing" below. If you experience problems in the field, see "Troubleshooting".

Refer to RHIB_processing_tutorial.docx for a visual explanation of the tools that are most useful in the field.

## Contents of package
The package contains the following functions and scripts:
- **RHIBproc**:  top level script that manages file structure, parsing of raw data, processing of velocities, saving processed data, plotting and saving figures
    - **ParseDeployment**: manages the parsing of data from IMU, GPS, and ADCP - **can be run independently**
        - **parse_imu**: parses data from IMU
        - **parse_rdi_adcp**: parses data from an RDI ADCP
        - **parse_gps**: parses data from GPS
    - **ProcADCP**: manages the processing of ADCP data - **can be run independently**
        - **nucRepair**: deals with occasional anomalies in timestamps from the RHIB computer
        - **compute_vessel_vel**: computes the RHIB velocity based on the method input in RHIBproc
        - **gps_ltln2vel**: computes the RHIB velocity if vessel_vel_method='GPRMC distance/time'
        - **gps_line_interp**: matches GPS heading entries with GPS time
        - **adcp_beam2earth**: transforms velocities from beam coordinates to Earth coordinates
    - **ClipAirTime**: identifies data collected while RHIB is out of water (based on low correlation and echo intensity) and clips it from the record - **can be run independently**
    - **PlotTrack**: plots the GPS track for the given deployment and colors it by time, if data is collected in/around LeConte Bay it also inserts a map of the bay showing where the data was collected - **can be run independently**
        - **Draw_LeConteCoastline**: adds coastline to map of GPS track (if data is from LeConte). Also includes option to plot 8/28/2023 terminus line.
    - **PlotBeams**: plots raw beam data, user can select beam velocity, correlation, or echo intensity - **can be run independently**
    - **PlotENU**: plots rotated velocities and error velocity - **can be run independently**

- **Interactive_LocateBottom**: top level script that provides an interface for the user to experiment with different threshold levels and manually exclude noisy portions of backscatter data to iteratively identify bottom contours
    - **LocateBottom**: This function identifies bottom contours from peaks in backscatter data (indicating hard surfaces) based on default or input thresholds. Runs Echo2Backscatter if backscatter field does not exist.
        - **Echo2Backscatter**: converts echo intensity to backscatter, accounting for beam spread and water absorption

- **CreateQCMasks**: creates masks based on default or input thresholds for bottom contours, correlation, echo intensity, turn rate, etc. which can be applied to beam data or combined and applied to ENU velocity

- **LocateFeature**: top level script to display beam data in an interactive figure used to identify features in the time domain of individual beams and locate them in space. To be used after processing data.
    - **LoadDeployment**: displays a list of processed files in the specified directory and the user enters the line number of the desired file to load the data - **can be run independently**
    - **AddTerm**: For use when near real-time terminus lines are being generated in the field. Displays a list of terminus files for user to select from. Terminus line will be added to map.
    - **adcp_earth2beam**: transforms rhib velocity from earth coordinates to beam coordinates for removing from beam velocity
    - **beamlocations**: uses rhib heading and tilt, beam angles, and depth to calculate the location of each point of beam data
    - **Draw_LeConteCoastine**: adds LeConte coastline to interactive map (if data is from LeConte). Also includes option to plot 8/28/2023 terminus line. 

- **DefineTransects**: creates an interactive figure that can be used to identify endpoints of transect within a deployment by clicking on the map. Endpoints are converted to time and data indices and saved to a separate file.

- **prep_nbeam_solutions**: calculates replacement values for missing beam data for '3-beam solutions'. This function is included for completeness, but has not been integrated into a workflow with the rest of the package. 

- Data files:
    - Alaska_Coast_63360_In: coastline file
    - LeConteTerminusAug282023: terminus line
- Tutorial (Brief description of how to work with functions/scripts that are most useful in the field, with screenshots)
    - RHIB_processing_tutorial.docx


## How to use RHIB_ADCP_processing
### Utilizing RHIBproc
RHIBproc is the top level script that manages everything. It expects to be in (or pointed to) a directory that contains a folder named 'raw/'. Within 'raw/', it expects to find folders named for each RHIB (Aires, Polly, etc.) and within that, the deployment file. The complete file path should be: raw/rhibname/deployment#/...

Depending on the ADCP installation and deployment details, there are a few options that need to be defined near the top of RHIBproc under the section titled "CUSTOMIZE PROCESSING DETAILS HERE".
- parse_nuc_timestamps
    - set to true to use the RHIBs computer time (which should be synced to the GPS clock) as timestamped for each ADCP ping instead of the ADCP clock  
- gps_timestamp
    - at this time, this should always be set to false
    - intention for this is to set up a means for reconciling RHIB computer time with GPS clock if initial synchronization fails (or to reconcile clock drift if that is an issue)
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
- minadcp
    - set a minimum total file size for ADCP data (in MB) in order to process ADCP (goal is to ignore test runs of the RHIB where no sampling occurred)
- mingps
    - set a minimum total file size for GPS data (in MB) in order to save GPS data (goal is to save GPS data when ADCP is turned off)
- addterm
    - set to 1 to include a terminus line from 8/2023 on the map of boat tracks that is auto-generated
    - the simple coastline included in that map shows the fjord ending 500-1000m short of the current terminus
    - this terminus line just provides a point of reference for the location of the boat tracks
- test, offset_adj
    - use these to experiment with different ADCP heading offsets 
    - when test=1, offset_adj will be added to the offset (defined below) 
    - within the processed folder, a new folder is created and named with the offset_adj value so that several versions can be created without overwriting each other
- serial and offset
    - to deal with potential inconsistencies with the installation of the ADCP in the RHIB, you can define the angle of offset for a particular ADCP by identifying the instrument serial number and its offset
    - for 2022/2023/2024, the two ADCPs being used are a Sentinel V (serial #24653) and a Workhorse (serial #14185)

When the above settings are entered as desired, the script just needs to be run. It will prompt you to confirm the serial #s and offsets, then run through the processing of all files in the specified directory, save the processed file, and create and save plots of the GPS track, beam velocities, correlation, echo intensity, and rotated velocities. The script can be run every time a new deployment is added to the directory or after several deployments have been added. As long as overwrite=false, it will only process the new files. 

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
LoadDeployment provides a convenient way to look up filenames and load processed data. basepath is the directory in which the processed folder is located. 

	adcp = LoadDeployment(basepath);
	
This will display a numbered list of all processed files contained in the specified directory (and subdirectories). Enter the line number of the desired file and the data is loaded into the adcp structure.

Additional outputs can be designated to load other datasets (if they have been created) and information about the file path

        [adcp,xsect,ctd,folder,filepath] = LoadDeployment(basepath);

    - xsect is a structure containing the times of endpoints and data indices for each transect within a deployment
        - this file is created using DefineTransects, described below
    - ctd is a structure containing the CTD data collected during the deployment
        - this file is created separately (the code is not included in this package)
    - folder and filepath show where the processed files were sourced from

### Defining endpoints of transects
DefineTransects is a script that displays an interactive figure in which the user can define the endpoints of transects by clicking on a map of the boat tracks.

Declare base path (the directory in which the processed folder is located) at the top and then run the script.

An interactive figure will display with a map of the boat tracks on the left and, initially, two boxes on the right. The boat tracks are colored by time with the corresponding hours:minutes displayed on the colorbar. Use the axes tools to zoom/pan to the desired portion of the deployment. Be sure to zoom in enough that each data point has a distinct location. Define start and end points for each transect by clicking on the boat tracks (the data point nearest in space to the location clicked will be selected). Deselect axes tools to enable point selection (i.e., if the zoom tool is selected, clicking on the plot will only zoom). Points must be selected in time order (start at the blue end). Dots will appear on the map over each data point selected (green for start, red for end), start and finish boxes will be populated with each data point selection, and additional boxes will appear as necessary. When satisfied with the points selected, click "Save and Exit". The start/end times and indices included in each transect will be saved to a separate file within the processed deployment folder and the figure will automatically close. If the figure is closed without clicking "Save and Exit", all endpoints will be lost.

### Quick and dirty identification of bottom contours
LocateBottom identifies bottom contours based on the peak backscatter (backscatter is calculated from echo intensity, the peak indicates a return from a hard surface). It is expected that this function, with the default thresholds, will miss some bottom contours and identify some random noise as bottom contours. The identification process can be tuned by adjusting thresholds via optional inputs, but the default thresholds generally do well enough to improve data visualization in the field.

        adcp = LocateBottom(adcp);

This adds the bottom_mask field (among others) to the adcp structure. This is a separate mask for each beam, which can be applied to beam data. Multiply the masks together to get a single mask that can be applied to the processed velocity.

        botmask = adcp.bottom_mask(:,1,:).*adcp.bottom_mask(:,2,:).*adcp.bottom_mask(:,3,:).*adcp.bottom_mask(:,4,:).*adcp.bottom_mask(:,5,:);

        botmask = [botmask botmask botmask botmask];

        adcp.vel = adcp.vel.*botmask;

At this point, PlotENU can be used to visualize the data.

        fig = PlotENU(adcp);

Note that, due to the inaccuracy of the bottom contour identification, the results should not be saved as processed data. Better bottom contour identification can be obtained by adjusting the thresholds in LocateBottom, but the most accurate results require the use of Interactive_LocateBottom. However, this process is somewhat time-consuming and is best undertaken during post-processing after returning from the field. Directions are included in the summary at the top of Interactive_LocateBottom.

### Applying some basic quality control
After identifying bottom contours (see above), CreateQCMasks can be used to mask out potentially bad data. By default, the function masks out the bottom 10% of the water column and any data with a correlation below 64. With the RHIBs, it is also useful to set a threshold for the turn rate to mask out times when the boat is turning too quickly to get accurate heading/motion from the GPS.

        QC = CreateQCMasks(adcp,turn=.15);

The output structure contains separate masks for each threshold and combo_mask is the combination of all of them. Just as with the bottom mask (above), there are separate masks for each beam and they can be multiplied together then applied to the processed velocity. Use a similar sequence of steps to apply the mask to adcp.vel to use PlotENU to visualize the results.

Note that the errors in bottom identification will feed through to the QC mask, so the results should be used for plotting only.

### Identifying features in beam data and locating them in space
LocateFeature is the top level script that will set up an interactive plot for identifying features. Declare basepath at the top. If new terminus lines are being generated in the field, set addterm=1 and declare the subfolder in which the terminus files are located (expected to be located within basepath).It will bring up a list of processed files to chose from (see Loading processed data above). If addterm is turned on, the start date/time of the loaded file will be displayed along with a list of the available terminus lines to select from. After loading the data, it removes RHIB velocity from the beam velocities and calculates the actual location of each data point (based on tilt, heading, beam angle, and depth). A figure is displayed which enables the user to visually identify features of interest in the beam data and locate them in space by clicking on the time series. 

The interactive figure is initially displayed with beam velocities for each beam (RHIB velocity has been removed) and a blank map. If data was collected at LeConte, the map will include the coastline local to the data collected. However, the coastline is not accurate near the terminus (making terminus lines very useful). Three buttons next to the beam data (just above the colorbar) allow the user to toggle between beam velocity, correlation, and echo intensity. The axes containing beam data are linked so that zooming in on one axes zooms all of them. The user can explore any of the beam data to visually identify features. A mouse click (as long as none of the axes tools are selected) on any point in the beam data will plot a red dot on the map at the location of that data point. Click on any dot to display its coordinates. Subsequent clicks on the beam data will add dots to the map. Press the "Clear Points" button to clear the map and begin again.

## Troubleshooting
This section provides some workarounds in the event that it is discovered in the field that some requirements are missing

| Problem								| Workaround															|
| :---									| :------------															|
| using MATLAB release prior to R2019b		| Unfortunately there is no easy solution to this. Many of the functions are built with argument blocks. Those would need to be removed and defaults, validations, and optional inputs would need to be handled another way	|
| missing Mapping/Navigation toolboxes		| In RHIBproc, comment out lines labeled %Map RHIB track (probably around line 110)		|
| missing m_map					| In ProcADCP, comment out lines labeled %convert lat, lon to UTM (probably around line 30)	|
| missing cmocean				| Select new colormap in PlotBeams (~line 20) and PlotENU (~line32)				| 



## Future developments
- Nortek processing
- Clean up compute_vessel_vel
- Handling of timestamped GPS data files


## Credits
The RHIB_ADCP_processing package is based heavily on the ROSE_code package developed by Dylan Winters. Many of the low level functions are nearly exactly as he wrote them. The current package represents an overhaul of the code framework by Bridget Ovall to update, simplify, consolidate, and debug the package. Additional capability was added for identifying features in beam data and locating them in space.


