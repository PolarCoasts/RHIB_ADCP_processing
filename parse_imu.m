%% parse_imu.m
%
% Usage
%   imu = parse_imu(dat_or_file, parse_nuc_timestamps)
%
% Inputs
% - dat_or_file
%   This can be a filename, cell array of filenames, the output of MATLAB's
%   "dir" command, or an array of binary data.
% - parse_nuc_timestamps (logical)
% | Flag to parse Nuc timestamps inserted into the _timestamped* files from ROSE deployments.
%
% Outputs
% - imu
%   Data structure containing IMU fields. The field and subfield structure matches the fields described in the LORD IMU manuals.
%
% Original author: Dylan Winters

function imu = parse_imu(dat_or_file,parse_nuc_timestamps)

    %% Main parsing routine
    % 1) Load binary data
    if iscell(dat_or_file)
        % Cell array of filenames
        dat = load_data(dat_or_file);
    elseif isstruct(dat_or_file)
        % File info struct from dir()
        dat = load_data(fullfile({dat_or_file.folder},{dat_or_file.name}));
    elseif isstr(dat_or_file)
        % Single filename
        dat = load_data({dat_or_file});
    else
        % Treat input as raw data
        dat = dat_or_file;
    end

    % 2) Locate & validate data packets
    header = find_headers(dat);

    % 3) Convert binary data to struct
    imu = parse_data(header, dat);

    %%% Sub-functions
    %----------------------------------------------------------
    % Locate headers in the 3DM-GX5-25 binary output
    %----------------------------------------------------------
    function header = find_headers(dat)
    % Find sequences of SYNC1 and SYNC2 bytes (0x75,0x65).
    % These are the first two bytes of all headers.
        h = find(dat(1:end-1) == hex2dec('75') & ...
                 dat(2:end)   == hex2dec('65'));

        % Throw out trailing headers with no payload
        h = h(length(dat) - h > 2);

        % Look for timestamps inserted by ROSE computer
        if parse_nuc_timestamps
            % Discard first header if preceeding timestamp is incomplete
            if ~isempty(h)
                if h(1) < 8
                    h = h(2:end);
                end
                ts = double(dat(h - [7:-1:1]));
                ts(:,1) = ts(:,1) + 2000; % add century
                ts(:,6) = ts(:,6) + ts(:,7)/100; % add ms to s
                ts = datenum(ts(:,1:6));
            else
                ts = [];
            end
        end

        % The third byte is the 'descriptor set', which signifies the payload type.
        d = double(dat(h + 2));

        % The fourth byte is the payload length.
        l = double(dat(h + 3));

        % Verify checksums of each packet payload
        kp = true(size(h));
        for n = 1:length(h)
            % Stop if we reach EoF before packet end
            if h(n) + l(n)-1 + 6 <= length(dat)
                % Extract packet payload
                pp = dat(h(n) + [0:l(n)+3]);
                % Extract packet checksum
                chk1 = double(dat((h(n) + l(n)+3) + [1:2]));
                chk1 = bitshift(chk1(1),8) + chk1(2);

                % Compute packet checksum (16-bit Fletcher checksum)
                sum1 = 0;
                sum2 = 0;
                for i = 1:length(pp)
                    sum1 = mod(sum1 + double(pp(i)),2^8);
                    sum2 = mod(sum2 + sum1,2^8);
                end
                chk2 = bitshift(sum1,8) + sum2;

                % Discard packet if checksums don't match
                if chk2 ~= chk1
                    kp(n) = false;
                end

            else % EoF reached before packet end; discard
            kp(n) = false;
            end
        end

        % Eliminate headers with invalid checksums
        header.index = h(kp);
        header.descriptor = d(kp);
        header.length = l(kp);
        if parse_nuc_timestamps
            header.ts = ts(kp);
        end
    end

    %----------------------------------------------------------
    % Read and concatenate data in the given list of files
    %----------------------------------------------------------
    function dat = load_data(files)
        dat = [];
        for i = 1:length(files)
            if ~exist(files{i},'file')
                error('File not found: %s',files{i})
            end
            [~,fname,fext] = fileparts(files{i});
            fd = fopen(files{i},'r','ieee-le');
            dat = cat(1,dat,uint8(fread(fd,inf,'uint8')));
            fclose(fd);
        end
    end

    %----------------------------------------------------------
    % Convert raw binary data to a MATLAB struct
    %----------------------------------------------------------
    function output = parse_data(header, dat)
        if length(header) == 0
            output = [];
            return
        end

        output = struct(); % initialize output structure
        output.units = struct(); % initialize units structure

        [d, f, id] = unique(header.descriptor);
        len = header.length(f);
        dat_preproc = cell(length(d),1);
        for i = 1:length(d)
            dat_preproc{i} = dat(header.index(id==i)+2 + [0:len(i)+1]);
        end

        for i = 1:length(d) % for each type of payload encountered while finding headers...
            nb_proc = 2;
            while nb_proc < size(dat_preproc{i},2) % extract fields 1-by-1
                flen = unique(dat_preproc{i}(:,nb_proc+1)); % get field length
                fdesc = unique(dat_preproc{i}(:,nb_proc+2)); % and descriptor
                [dname fname subfields] = imu_field_defs(d(i),fdesc); % get subfield info

                % initialize output fields/subfields
                if ~isfield(output,dname)
                    output.(dname) = struct();
                    % store ROSE timestamps
                    if parse_nuc_timestamps
                        output.(dname).nuc_time = header.ts(id==i);
                    end
                end

                if ~isfield(output.(dname),fname) && ~isempty(fname)
                    output.(dname).(fname) = struct();
                end

                for sf = 1:length(subfields)
                    % store unit information
                    %fprintf('parse_imu: field fname: %s: subfield: %s\n',fname,subfields(sf).name); %debug
                    output.units.(dname).(fname).(subfields(sf).name) = subfields(sf).units;
                    % compute subfield length
                    if sf==length(subfields)
                        sf_len = flen-2 - subfields(end).offset;
                    else
                        sf_len = subfields(sf+1).offset - subfields(sf).offset;
                    end
                    % compute subfield index in pre-processed data
                    sf_idx = nb_proc + 3 + subfields(sf).offset + [0:sf_len-1];
                    % convert 8-bit integers to final datatype with MATLAB's typecast function
                    % this requires some reshaping, etc. to be fast
                    output.(dname).(fname).(subfields(sf).name) = ...
                        double(typecast(reshape(fliplr(dat_preproc{i}(:,sf_idx))',1,[]),subfields(sf).type));
                end
                nb_proc = nb_proc + double(flen);
            end
        end
    end % of parse_data()


    %----------------------------------------------------------
    % Define subfield names, byte offsets, subfield lengths, and
    % datatypes based on the payload descriptor.
    %----------------------------------------------------------
    function [dname fname subfields] = imu_field_defs(descriptor,fdesc)
        dname = '';
        fname = '';
        subfields = struct();
        switch dec2hex(descriptor,2) % Descriptor set byte
          case '80' % IMU Data
            dname = 'IMU';
            switch dec2hex(fdesc,2)
              case '04'
                fname = 'scaled_accelerometer_vector';
                subfields = struct(...
                    'name', {'x_accel','y_accel','z_accel'},...
                    'offset', {0,4,8},...
                    'type', {'single','single','single'},...
                    'units', {'g','g','g'});
              case '05'
                fname = 'scaled_gyro_vector';
                subfields = struct(...
                    'name', {'x_gyro','y_gyro','z_gyro'},...
                    'offset', {0,4,8},...
                    'type',{'single','single','single'},...
                    'units',{'rad/s','rad/s','rad/s'});
              case '06'
                fname = 'scaled_magnetometer_vector';
                subfields = struct(...
                    'name', {'x_mag','y_mag','z_mag'},...
                    'offset', {0,4,8},...
                    'type',{'single', 'single', 'single'},...
                    'units', {'gauss','gauss','gauss'});
              case '17'
                fname = 'scaled_ambient_pressure';
              case '07'
                fname = 'delta_theta_vector';
              case '08'
                fname = 'delta_velocity_vector';
              case '09'
                fname = 'cf_orientation_matrix';
              case '0A'
                fname = 'cf_quaternion';
              case '0C'
                fname = 'cf_euler_angles';
                subfields = struct(...
                    'name', {'roll','pitch','yaw'},...
                    'offset', {0,4,8},...
                    'type', {'single','single','single'},...
                    'units', {'radians','radians','radians'});
              case '10'
                fname = 'cf_stabilized_north_vector';
              case '11'
                fname = 'cf_stabilized_up_vector';
              case '12'
                fname = 'gps_correlation_timestamp';
                subfields = struct(...
                    'name', {'gps_time_of_week','gps_week_number','timestamp_flags'},...
                    'offset', {0,8,10},...
                    'type', {'double','uint16','uint16'},...
                    'units', {'seconds','n/a','see manual'});
            end
          case '81' % GNSS Data
            dname = 'GNSS';
            switch dec2hex(fdesc,2)
              case '03'
                fname = 'llh_position';
                subfields = struct(...
                    'name', {'latitude' ,...
                             'longitude',...
                             'height_above_ellipsoid',...
                             'height_above_msl',...
                             'horizontal_accuracy',...
                             'vertical_accuracy',...
                             'valid_flags'} ,...
                    'offset',{0,8,16,24,32,36,40},...
                    'type', {'double',...
                             'double',...
                             'double',...
                             'double',...
                             'single',...
                             'single',...
                             'uint16'},...
                    'units', {'decimal degrees',...
                              'decimal degrees',...
                              'meters',...
                              'meters',...
                              'meters',...
                              'meters',...
                              'see manual'});
              case '04'
                fname = 'position_eath_centered_earth_fixed_frame';
                subfields = struct(...
                    'name', {'x_pos','y_pos','z_pos','pos_accuracy','valid_flags'},...
                    'offset', {0,8,16,24,28},...
                    'type', {'double','double','double','single','uint16'},...
                    'units',{'meters','meters','meters','meters','see manual'});
              case '05'
                fname = 'velocity_north_east_down_frame';
                subfields = struct(...
                    'name', {'north',...
                             'east',...
                             'down',...
                             'speed',...
                             'ground_speed',...
                             'heading',...
                             'speed_accuracy',...
                             'heading_accuracy',...
                             'valid_flags'},...
                    'offset', {0,4,8,12,16,20,24,28,32},...
                    'type', {'single',...
                             'single',...
                             'single',...
                             'single',...
                             'single',...
                             'single',...
                             'single',...
                             'single',...
                             'uint16'},...
                    'units', {'m/sec',...
                              'm/sec',...
                              'm/sec',...
                              'm/sec',...
                              'm/sec',...
                              'decimal degrees',...
                              'm/sec',...
                              'decimal degrees',...
                              'see manual'});
              case '06'
                fname = 'velocity_eath_centered_earth_fixed_frame';
                subfields = struct(...
                    'name', {'x_vel','y_vel','z_vel','vel_accuracy','valid_flags'},...
                    'offset', {0,4,8,12,16},...
                    'type', {'single','single','single','single','uint16'},...
                    'units',{'m/sec','m/sec','m/sec','m/sec','see manual'});
              case '07'
                fname = 'DOP_data';
              case '08'
                fname = 'UTC_time';
                subfields = struct(...
                    'name',{'year','month','day','hour','minute','second',...
                            'millisecond','valid_flags'},...
                    'offset',{0,2,3,4,5,6,7,11},...
                    'type',{'uint16','uint8','uint8','uint8','uint8',...
                            'uint8','uint32','uint16'},...
                    'units',{'years','months','days','hours','minutes',...
                             'seconds','milliseconds','see manual'});
              case '09'
                fname = 'GPS_time';
                subfields = struct(...
                    'name',{'time_of_week','week_number','valid_flags'},...
                    'offset',{0,8,10},...
                    'type',{'double','uint16','uint16'},...
                    'units',{'seconds','n/a','see manual'});
              case '0A'
                fname = 'clock_information';
              case '0B'
                fname = 'gnss_fix_information';
              case '0C'
                fname = 'space_vehicle_information';
              case '0D'
                fname = 'hardware_status';
              case '0E'
                fname = 'dgnss_information';
              case '0F'
                fname = 'dgnss_channel_status';
            end
          case '82' % Estimation Filter (Attitude) Data
            dname = 'attitude';
            switch dec2hex(fdesc,2)
              case '10'
                fname = 'filter_status';
              case '11'
                fname = 'gps_timestamp';
                subfields = struct(...
                    'name',  {'time_of_week'  ,...
                              'week_number'   ,...
                              'valid'}        ,...
                    'offset',{0,8,10}         ,...
                    'type',  {'double'        ,...
                              'uint16'        ,...
                              'uint16'}       ,...
                    'units', {'seconds'       ,...
                              'n/a'           ,...
                              '1=valid, 0=invalid'});
              case '03'
                fname = 'orientation_quaternion';
              case '12'
                fname = 'attitude_uncertainty_quaternion_elements';
              case '05'
                fname = 'orientation_euler_angles';
                subfields = struct(...
                    'name',  {'roll'    ,...
                              'pitch'   ,...
                              'yaw'     ,...
                              'valid'}  ,...
                    'offset',{0,4,8,12} ,...
                    'type',  {'single'  ,...
                              'single'  ,...
                              'single'  ,...
                              'uint16'} ,...
                    'units', {'radians' ,...
                              'radians' ,...
                              'radians' ,...
                              '1=valid, 0=invalid'});
              case '0A'
                fname = 'attitude_uncertainty_euler_angles';
              case '04'
                fname = 'orientation_matrix';
              case '0E'
                fname = 'compensated_angular_rate';
                subfields = struct(...
                    'name',  {'X'       ,...
                              'Y'       ,...
                              'Z'       ,...
                              'valid'}  ,...
                    'offset',{0,4,8,12} ,...
                    'type',  {'single'  ,...
                              'single'  ,...
                              'single'  ,...
                              'uint16'} ,...
                    'units', {'rads/sec' ,...
                              'rads/sec' ,...
                              'rads/sec' ,...
                              '1=valid, 0=invalid'});
              case '06'
                fname = 'gyro_bias';
              case '0B'
                fname = 'gyro_bias_uncertainty';
              case '1C'
                fname = 'compensated_acceleration';
              case '0D'
                fname = 'linear_acceleration';
                subfields = struct(...
                    'name',  {'X'       ,...
                              'Y'       ,...
                              'Z'       ,...
                              'valid'}  ,...
                    'offset',{0,4,8,12} ,...
                    'type',  {'single'  ,...
                              'single'  ,...
                              'single'  ,...
                              'uint16'} ,...
                    'units', {'m/sec^2' ,...
                              'm/sec^2' ,...
                              'm/sec^2' ,...
                              '1=valid, 0=invalid'});
              case '21'
                fname = 'pressure_altitude';
              case '13'
                fname = 'gravity_vector';
              case '0F'
                fname = 'wgs84_local_gravity_magnitude';
              case '14'
                fname = 'heading_update_source_state';
                subfields = struct(...
                    'name',  {'heading'                                ,...
                              'heading_1_sigma_uncertainty'             ,...
                              'source'                                  ,...
                              'valid'}                                  ,...
                    'offset',{0,4,8,10}                                ,...
                    'type',  {'single'                                 ,...
                              'single'                                 ,...
                              'uint16'                                 ,...
                              'uint16'}                                ,...
                    'units', {'radians'                                ,...
                              'radians'                                ,...
                              '0=no source, 1=Magnetometer, 4=External',...
                              '1=valid, 0=invalid'});
              case '15'
                fname = 'magnetic_model_solution';
              case '25'
                fname = 'mag_auto_hard_iron_offset';
              case '28'
                fname = 'mag_auto_hard_iron_offset_uncertainty';
              case '26'
                fname = 'mag_auto_soft_iron_matrix';
              case '29'
                fname = 'mag_auto_soft_iron_matrix_uncertainty';
            end
        end
    end % of imu_field_defs

end % of parse_imu()
