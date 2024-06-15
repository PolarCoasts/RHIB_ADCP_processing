% This is a top-level script that handles all ADCP processing from RHIBs
%   - Processes all unprocessed files in 'raw/' subfolder of working directory
%       - Parses ADCP, GPS, and IMU data from UBOX
%       - Rotates velocity to ENU and removes RHIB velocity
%       - Saves processed data
%       - Creates and saves some basic plots of initial data
%
% To run:
%   - First, cd to data folder containing 'raw/' subfolder OR set basepath to folder containing 'raw/'
%   - Customize processing options in first section below
%   - Enter serial numbers and offset angle for each ADCP 
%   - Run script (You will be prompted to confirm serial numbers and offsets to continue)

clear


%% ** CUSTOMIZE PROCESSING DETAILS HERE **  

% ========== Processing options =========================================================
% set basepath to directory containing 'raw/' (leave empty to use working directory)
basepath=[];
% use nuc time
parse_nuc_timestamps=true;
% use nuc time for gps, too
gps_timestamp=false;
% how to handle ship motion
vessel_vel_method = 'GPRMC groundspeed and course';
% weighting for beam 5 in transforming to earth coordinates
beam5_weight=1;
% overwrite existing processed files 
overwrite=false;
% automatically trim leading/trailing portion of record collected in air
clipAir=true;
% minimum file sizes to process (MB)
minadcp=8; mingps=1;
% add 8/28/2023 terminus line to map
addterm=1;
% adjust offset angle when searching for good match
test=0;
offset_adj=-2;
% =======================================================================================

% === Define ADCP offset for each instrument used =======================================
serial=[14158; 24653]; 
offset=[45; 133];
% =======================================================================================

%% Prompt user to confirm ADCP offsets

disp(table(serial,offset))
userinfo=input("Is this correct? (y/n)",'s');
if isempty(userinfo)
    userinfo='n';
end
if userinfo~='y'
    fprintf("Please enter the correct values in RHIBproc.m")
    return
end

%% Define file structure and get list of RHIBs
raw_dir=[basepath 'raw/'];             %directory containing raw data from UBOX
if test==1
    proc_dir=[basepath 'processed/adj_' num2str(offset_adj) '/'];
    offset=offset+offset_adj;
else
    proc_dir=[basepath 'processed/'];      %directory for saving processed files
end

if ~exist(raw_dir,'dir')
    error('No raw files exist in this directory. Please change directories.')
end

% find subfolders for each rhib
rhibs=dir(raw_dir);
rhibs(strcmp({rhibs.name},'.') | strcmp({rhibs.name},'..') | strcmp({rhibs.name},'.DS_Store') | strcmp({rhibs.name},'.AppleDouble') | strcmp({rhibs.name},'._.DS_Store'))=[];
rhibs(~[rhibs.isdir])=[];

%% Loop through existing files and process any that have not been processed (or reprocess if overwrite=true)

for i=1:length(rhibs)
    rhibname=rhibs(i).name; 
    deps=dir(fullfile(raw_dir,rhibname));
    deps=deps(contains({deps.name},'deploy'));
    if ~isempty(deps)
        for j=1:length(deps)
            depname=deps(j).name;
            depfile=fullfile(raw_dir,rhibname,depname);
            uboxfile=dir(depfile);
            uboxfile=uboxfile(contains({uboxfile.name},'UBOX'));
            uboxfile(contains({uboxfile.name},'.'))=[];
            if ~isempty(uboxfile)
                uboxname=uboxfile.name;
    
                rawfile=fullfile(depfile,uboxname);
                procfile=fullfile(proc_dir,rhibname,depname,uboxname);
                % Continue if processed file does not already exist or if set to overwrite existing
                if ~exist(procfile,'dir') || overwrite
                    % continue with full processing if deployment contains minimum amount of ADCP data
                    adcpfile=dir([rawfile '/ADCP']);
                    adcpfile=adcpfile(contains({adcpfile.name},'ADCP_raw'));
                    adcpsize=0;
                    for f=1:length(adcpfile)
                        adcpsize=adcpsize+adcpfile(f).bytes/1e6;
                    end
                    if adcpsize>minadcp
                        fprintf(['\nProcessing ' depname '...\n'])
                        data_raw=ParseDeployment(rawfile,parse_nuc_timestamps,gps_timestamp);
                        if ~isempty(data_raw.adcp.time)
                        
                            %put gps in separate file for using with other instruments
                            gps.time=data_raw.gps.GPRMC.dn;
                            gps.lat=data_raw.gps.GPRMC.lat;
                            gps.lon=data_raw.gps.GPRMC.lon;
                                        
                            fprintf('Preparing to transform velocities...\n')
                            yaw_offset=offset(serial==data_raw.adcp.config.serial_number);
                            if isempty(yaw_offset)
                                disp(data_raw.adcp.config.serial_number)
                                error("No match found for instrument serial number. Check values entered in RHIBproc.m.")
                            end
                            adcp=ProcADCP(data_raw,yaw_offset,vessel_vel_method,beam5_weight);
                            fprintf('Transformation complete... saving file...')
                
                            if clipAir
                                adcp=ClipAirTime(adcp);
                            end
                            
                            % save file
                            if ~exist(procfile,'dir')
                                mkdir(procfile)
                            end   
                            save('-v7.3',fullfile(procfile,['gps_' depname '.mat']),'gps')
                            save('-v7.3',fullfile(procfile,['adcp_' depname '.mat']),'adcp');
                            
                            % plot some figures
                            fprintf('\nPlotting and saving figures...')
                            plotpath=procfile+"/plots/";
                            if ~exist(plotpath,'dir')
                                mkdir(plotpath)
                            end
                            
                            if ~test
                                % Map RHIB track
                                mapfig=PlotTrack(adcp);
                                exportgraphics(mapfig,plotpath+"map.png")
                                close(mapfig)
                    
                                % Beam velocities
                                bvelfig=PlotBeams(adcp,'bvel');
                                exportgraphics(bvelfig,plotpath+"beamvel.png")
                                close(bvelfig)
                    
                                % Echo intensities
                                echofig=PlotBeams(adcp,'echo');
                                exportgraphics(echofig,plotpath+"echointensity.png")
                                close(echofig)
                    
                                % Correlation
                                corrfig=PlotBeams(adcp,'corr');
                                exportgraphics(corrfig,plotpath+"correlation.png")
                                close(corrfig)
                            end
                
                            % ENU velocity
                            ENUfig=PlotENU(adcp);
                            exportgraphics(ENUfig,plotpath+"ENU.png")
                            close(ENUfig)
                            
                            fprintf(['\n' depname ' complete.\n'])
                        else
                            fprintf(['\n' depname ' is empty.\n'])
                        end
                    else
                        % if ADCP data doesn't meet minimum size requirement, check GPS data
                        % (checking for deployments where the ADCP is turned off, but we still want gps data for other instruments
                        gpsfile=dir([rawfile '/GPS']);
                        gpsfile=gpsfile(contains({gpsfile.name},'GPS_2'));
                        gpssize=0;
                        for g=1:length(gpsfile)
                            gpssize=gpssize+gpsfile(g).bytes/1e6;
                        end
                        if gpssize>mingps
                            fprintf(['\nProcessing ' depname '...\n'])
                            if gps_timestamp
                                files.gps = dir(fullfile(rawfile,'GPS','GPS_timestamped*.log'));
                            else
                                files.gps = dir(fullfile(rawfile,'GPS','GPS_2*.log'));
                            end
                            data=struct('gps',[]);
                            % parse gps data only
                            if ~isempty(files.gps)
                                fprintf('ADCP data does not meet minimum file size, parsing and saving GPS only...')
                                data_raw.gps=parse_gps(files.gps);
                            end
                            %put gps in separate file for using with other instruments 
                            gps.time=data_raw.gps.GPRMC.dn;
                            gps.lat=data_raw.gps.GPRMC.lat;
                            gps.lon=data_raw.gps.GPRMC.lon;
                            %save gps file
                            if ~exist(procfile,'dir')
                                mkdir(procfile)
                            end   

                            save('-v7.3',fullfile(procfile,['gps_' depname '.mat']),'gps')
                            fprintf(['\n' depname ' complete.\n'])                            
                        end
                    end     
                end 
            end 

        end %processing this deployment
    end %loop thru deployments
end %loop thru rhibs
fprintf('\nAll files in this folder have been processed!\n')


