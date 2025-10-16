function data=ParseDeployment(rawfile,parse_nuc_timestamps)
% This function parses data from raw IMU, ADCP, and GPS files. 
% It is called by RHIBproc, but can also be used independently
% usage:
%   data = ParseDeployment(rawfile,parse_nuc_timestamps)


% find all files in deployment folder    
files.adcp = dir(fullfile(rawfile,'ADCP','*ADCP_timestamped*.bin'));
files.imu = dir(fullfile(rawfile,'IMU','IMU_timestamped*.bin'));
isNortek = all(startsWith({files.adcp.name},'Nortek'));

% grab the gps file with timestamps. If it doesn't exist, grab the regular one.
files.gps = dir(fullfile(rawfile,'GPS','GPS_timestamped*.log'));
if isempty(files.gps)
    files.gps = dir(fullfile(rawfile,'GPS','GPS_2*.log'));
end

% establish structure to load with parsed data
data=struct('adcp',[],'gps',[],'imu',[]);
fprintf('Parsing data...')

if ~isempty(files.imu)
    fprintf('IMU...')
    try
        data.imu=parse_imu(files.imu,parse_nuc_timestamps);
    catch imu_ME
        warning('\n%s:%s\nIMU will not be parsed.\n',imu_ME.identifier,imu_ME.message);
    end
end

if ~isempty(files.adcp)
    fprintf('ADCP...')
    %***********NORTEK PROCESSING NEEDS TO BE VERIFIED**********
    if isNortek
        error('Nortek processing is not yet functional')
        % data.adcp=parse_nortek_adcp(files.adcp,parse_nuc_timestamps);
    else
        data.adcp=parse_rdi_adcp(files.adcp,parse_nuc_timestamps);
    end
end

if ~isempty(files.gps)
    fprintf('GPS...')
    data.gps=parse_gps(files.gps);
    %if we have good timestamps, we can check for a clock mis-match
    if isfield(data.gps,'nuc_time')
        time_diff=abs(data.gps.nuc_time.dn(1)-data.gps.GPRMC.dn(1))*86400;
        if time_diff>1
            data.warning="nuc time is off by "+time_diff+" s";
            warning(data.warning)
        end
    end
end



fprintf('\nData parsing complete...\n')




