% This is a top-level script that handles all ADCP processing from RHIBs
%   - Processes all unprocessed files in 'raw/' subfolder of working directory
%       - Parses ADCP, GPS, and IMU data from UBOX
%       - Rotates velocity to ENU and removes RHIB velocity
%       - Saves processed data
%       - Creates and saves some basic plots of initial data
%
% To run:
%   - First, cd to data folder containing 'raw/' subfolder
%   - Customize processing options in first section below
%   - Enter serial numbers and offset angle for each ADCP 
%   - Run script (You will be prompted to confirm serial numbers and offsets to continue)

clear

%% ** CUSTOMIZE PROCESSING DETAILS HERE **  

% ========== Processing options =========================================================
% use nuc time
parse_nuc_timestamps=true;
% how to handle ship motion
vessel_vel_method = 'GPRMC groundspeed and course';
% weighting for beam 5 in transforming to earth coordinates
beam5_weight=1;
% overwrite existing processed files 
overwrite=false;
% automatically trim leading/trailing portion of record collected in air
clipAir=true;
% add 8/28/2023 terminus line to map
addterm=1;
% =======================================================================================

% === Define ADCP offset for each instrument used =======================================
serial=[14158; 24653]; 
offset=[45; 135];
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

%% Define file structure and get list of existing files

raw_dir='raw/';             %directory containing raw data from UBOX
proc_dir='proc/ADCP/';      %directory for saving processed files
if ~exist(raw_dir,'dir')
    error('No raw files exist in this directory. Please change directories.')
end
if ~exist(proc_dir,'dir')
    mkdir(proc_dir)
end

% find subfolders for each rhib
rhibs=dir(raw_dir);
rhibs(strcmp({rhibs.name},'.') | strcmp({rhibs.name},'..') | strcmp({rhibs.name},'.DS_Store'))=[];
rhibs(~[rhibs.isdir])=[];

%% Loop through existing files and process any that have not been processed (or reprocess if overwrite=true)

for i=1:length(rhibs)
    rhibname=rhibs(i).name; 
    deps=dir(fullfile(raw_dir,rhibname));
    deps=deps(contains({deps.name},'UBOX'));
    for j=1:length(deps)
        depname=deps(j).name;
        rawfile=fullfile(raw_dir,rhibname,depname);
        procfile=fullfile(proc_dir,rhibname,depname);
        % Continue if processed file does not already exist or if set to overwrite existing
        if ~exist(procfile,'dir') || overwrite
            fprintf(['\nProcessing ' depname '...\n'])
            data_raw=ParseDeployment(rawfile,parse_nuc_timestamps);
                        
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
            filepath=fullfile(proc_dir,rhibname,depname);
            if ~exist(filepath,'dir')
                mkdir(filepath)
            end    
            save('-v7.3',fullfile(filepath,['adcp_' depname '.mat']),'adcp');
            
            % plot some figures
            fprintf('\nPlotting and saving figures...')
            plotpath=filepath+"/plots/";
            if ~exist(plotpath,'dir')
                mkdir(plotpath)
            end

            % Map RHIB track
            mapfig=PlotTrack(adcp,addterm=addterm);
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

            % ENU velocity
            ENUfig=PlotENU(adcp);
            exportgraphics(ENUfig,plotpath+"ENU.png")
            close(ENUfig)
            
            fprintf(['\n' depname ' complete.\n'])
                        
        end %processing this deployment
    end %loop thru deployments
end %loop thru rhibs
fprintf('\nAll files in this folder have been processed!\n')


