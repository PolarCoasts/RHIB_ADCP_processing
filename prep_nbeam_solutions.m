%% prep_nbeam_solutions.m
% Usage: adcp = prep_nbeam_solutions(adcp,opt)
%
% Description:
%   Fill in NaN-masked beam velocity data with data from other beams. Uses the
%   Sentinel V's 5th beam to solve for missing beam data with the assumption that
%   towards-transducer velocity as estimated by each beam pair and as measured by
%   the 5th beam should be equal.
%
% Inputs: adcp - adcp structure returned by parse_adcp()
%         opt - options for 5-beam ADCP:
%               1 = set Z for pair containing missing data to beam 5 (maintain NaNs if beam 5 has missing data)
%               2 = set Z for pair containing missing data to Z from other pair (maintain NaNs if one beam from each pair has missing data)
%               note: in 4-beam ADCP, options have no effect
% Outputs: adcp - an equivalent structure with modified beam velocities.
%
% Author: Dylan Winters
% Created: 2022-02-21
% 
% Modifications made by: Bridget Ovall 
% 2022-04-05    Error corrected in function to identify which beams are NaN
% 2022-04-13    Protocol added for dealing with missing data in Beam 5
% 2022-04-26    Split protocol for 5-beam ADCP into two options (either use beam 5 or use estimate from one of the beam pairs to match vertical velocity)
%               Save bad_beams as a field in adcp to keep track of which beam scenarios exist
% 2024-11-17    Add handling of bad 5th beam so that it doesn't just pass NaNs through

function adcp = prep_nbeam_solutions(adcp,opt) 

% Get velocity dimensions
nb = size(adcp.vel,2); % number of beams
nc = size(adcp.vel,1); % number of depth cells
nt = size(adcp.vel,3); % number of samples

% Reshape velocity matrix to columns of beam data
vb = reshape(permute(adcp.vel,[3 1 2]),nc*nt,nb);

% Create a logical mask for NaN-valued beam data, i.e.
% 1 0 0 0 0 <-- beam 1 is bad
% 0 0 1 0 0 <-- beam 3 is bad
% 0 0 0 1 1 <-- beams 4 & 5 are bad, etc.
bmask = isnan(vb);

% Find all combinations of bad beams. These are just the unique rows of the above matrix.
[bad_beams, ~, type] = unique(bmask,'rows');
adcp.bad_beam_scenarios=bad_beams;

% Also define a function to convert arbitrary combinations of bad beams to
% unique integers by treating these rows as binary numbers:
id =@(bad_beams) sum(2.^bad_beams); % ** corrected from sum(2.^find(bad_beams)) 04/05/2022 BO **

% Loop over all types of bad beam combinations and fill in masked velocity data where possible.
for i = 1:size(bad_beams,1)
    % Get the indices of velocity entries with this type of beam failure
    idx = type == i;
    c = 1/(2*sind(adcp.config.beam_angle));

    % ====== 3-beam solutions for 4-beam ADCP ====== %
    if nb==4
    switch id(find(bad_beams(i,:)))
      % ====== 1 side beam bad ====== %
      % The best we can do with a 4-beam ADCP is set error velocity equal to
      % zero, i.e. impose that the estimate of Z velocity from both beam
      % pairs is equal, then solve for the missing beam. Beam 1 example:
      %
      %     Z1 = c*v1 + c*v2     (1) Z estimate from 1st beam pair
      %     Z2 = c*v3 + c*v4     (2) Z estimate from 2nd beam pair
      %
      % Then impose Z1 = Z2 and solve for v1:
      %
      %     c*v1 + c*v2 = c*v3 + c*v4
      %     ===>     v1 = v3 + v4 - v2
      %
      % Similar for other beams.
      case id(1) % only beam 1 bad
        % c*v1 + c*v2 = c*v3 + c*v4
        % ===>     v1 = v3 + v4 - v2
        vb(idx,1) = vb(idx,3) + vb(idx,4) - vb(idx,2);

      case id(2) % only beam 2 bad
        % c*v1 + c*v2 = c*v3 + c*v4
        % ===>     v2 = v3 + v4 - v1
        vb(idx,2) = vb(idx,3) + vb(idx,4) - vb(idx,1);

      case id(3) % only beam 3 bad
        % c*v1 + c*v2 = c*v3 + c*v4
        % ===>     v3 = v1 + v2 - v4
        vb(idx,3) = vb(idx,1) + vb(idx,2) - vb(idx,4);

      case id(4) % only beam 3 bad
        % c*v1 + c*v2 = c*v3 + c*v4
        % ===>     v4 = v1 + v2 - v3
        vb(idx,4) = vb(idx,1) + vb(idx,2) - vb(idx,3);
    end
    end

    % ====== 3- and 4-beam solutions for 5-beam ADCP ====== %
    if nb==5
        if opt==1 %using beam 5 for Z matching, let NaNs feed through if beam 5 is bad
            switch id(find(bad_beams(i,:)))

            % ====== 1 side beam bad ====== %
            % Each opposite-side pair of side beams gives an estimate of Z velocity. With
            % a single bad side beam, we can impose that its pair's estimate of Z velocity
            % is equal to beam 5's measurement, and reconstruct the bad beam's velocity.
            %
            % For example, if beam 1 is bad (c is a scale factor depending on beam angle):
            %
            % If opt=1,
            %     Z1 = c*v1 + c*v2   (1) Z velocity estimate from combining beams 1 & 2
            %     Z2 = v5            (2) Z velocity estimate directly from beam 5
            %
            % By imposing that Z1 = Z2, we can combine (1) and (2) to solve for v1:
            %
            %     v5 = c*v1 + c*v2
            % ==> v1 = (v5 - c*v2)/c
            %
            % Then for all entries where only beam 1 is NaN, we set beam 1 velocity to
            % (v5 - c*v2)/c
            %
            % The process is similar for any single bad side beam.
            %
            % If opt=2, set Z2 = c*v3 + c*v4 and solve for v1

            case id(1) % only beam 1 bad, as in example above
            %     v5 = c*v1 + c*v2
            % ==> v1 = (v5 - c*v2)/c
            vb(idx,1) = (vb(idx,5) - c*vb(idx,2))/c;

            case id(2) % only beam 2 bad
            %     v5 = c*v1 + c*v2
            % ==> v2 = (v5 - c*v1)/c
            vb(idx,2) = (vb(idx,5) - c*vb(idx,1))/c;

            case id(3) % only beam 3 bad
            %     v5 = c*v3 + c*v4
            % ==> v3 = (v5 - c*v4)/c
            vb(idx,3) = (vb(idx,5) - c*vb(idx,4))/c;

            case id(4) % only beam 4 bad
            %     v5 = c*v3 + c*v4
            % ==> v4 = (v5 - c*v3)/c
            vb(idx,4) = (vb(idx,5) - c*vb(idx,3))/c;
            
            % ===== only beam 5 bad ===== %                            
            case id(5) % only beam 5 bad, set to average Z from beam pairs
            %     v5 = c/2*(v1+v2+v3+v4)
            vb(idx,5) = c/2*(vb(idx,1) + vb(idx,2) + vb(idx,3) + vb(idx,4));

            % ====== 2 side beams bad ====== %
            % Because we can handle a single bad beam from the 1&2 beam pair and the 3&4 beam pair independently, 
            % we can also handle cases where a single beam is bad for both pairs:

            case id([1,3]) % beams 1 & 3 bad
            %     v5 = c*v1 + c*v2
            % ==> v1 = (v5 - c*v2)/c
            vb(idx,1) = (vb(idx,5) - c*vb(idx,2))/c;
            %     v5 = c*v3 + c*v4
            % ==> v3 = (v5 - c*v4)/c
            vb(idx,3) = (vb(idx,5) - c*vb(idx,4))/c;

            case id([1,4]) % beams 1 & 4 bad
            %     v5 = c*v1 + c*v2
            % ==> v1 = (v5 - c*v2)/c
            vb(idx,1) = (vb(idx,5) - c*vb(idx,2))/c;
            %     v5 = c*v3 + c*v4
            % ==> v4 = (v5 - c*v3)/c
            vb(idx,4) = (vb(idx,5) - c*vb(idx,3))/c;

            case id([2,3]) % beams 2 & 3 bad
            %     v5 = c*v1 + c*v2
            % ==> v2 = (v5 - c*v1)/c
            vb(idx,2) = (vb(idx,5) - c*vb(idx,1))/c;
            %     v5 = c*v3 + c*v4
            % ==> v3 = (v5 - c*v4)/c
            vb(idx,3) = (vb(idx,5) - c*vb(idx,4))/c;

            case id([2,4]) % beams 2 & 4 bad
            %     v5 = c*v1 + c*v2
            % ==> v2 = (v5 - c*v1)/c
            vb(idx,2) = (vb(idx,5) - c*vb(idx,1))/c;
            %     v5 = c*v3 + c*v4
            % ==> v4 = (v5 - c*v3)/c
            vb(idx,4) = (vb(idx,5) - c*vb(idx,3))/c;

            % ===== 1 side beam bad and beam 5 bad ===== %
            % we must force a traditional 3-beam solution and also calculate beam 5
            case id([1,5]) % beams 1 & 5 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v1 = v3 + v4 - v2
            vb(idx,1) = vb(idx,3) + vb(idx,4) - vb(idx,2);
            % v5 = c*v3 + c*v4
            vb(idx,5) = vb(idx,3) + vb(idx,4);
            
            case id([2,5])  % only beam 2 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v2 = v3 + v4 - v1
            vb(idx,2) = vb(idx,3) + vb(idx,4) - vb(idx,1);
            % v5 = c*v3 + c*v4
            vb(idx,5) = vb(idx,3) + vb(idx,4);

            case id([3,5]) % only beam 3 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v3 = v1 + v2 - v4
            vb(idx,3) = vb(idx,1) + vb(idx,2) - vb(idx,4);
            % v5 = c*v1 + c*v2
            vb(idx,5) = vb(idx,1) + vb(idx,2);

            case id([4,5]) % only beam 4 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v4 = v1 + v2 - v3
            vb(idx,4) = vb(idx,1) + vb(idx,2) - vb(idx,3);
            % v5 = c*v2 + c*v2
            vb(idx,5) = vb(idx,1) + vb(idx,2);
            end
           
        elseif opt==2 %set Z equal to estimate from other pair, let NaNs feed through if one beam from each pair is bad
            switch id(find(bad_beams(i,:)))

            % ====== 1 side beam bad ====== %
            % without using beam 5, this is the typical 3-beam solution
            case id(1) % only beam 1 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v1 = v3 + v4 - v2
            vb(idx,1) = vb(idx,3) + vb(idx,4) - vb(idx,2);

            case id(2)  % only beam 2 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v2 = v3 + v4 - v1
            vb(idx,2) = vb(idx,3) + vb(idx,4) - vb(idx,1);

            case id(3) % only beam 3 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v3 = v1 + v2 - v4
            vb(idx,3) = vb(idx,1) + vb(idx,2) - vb(idx,4);

            case id(4) % only beam 4 bad 
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v4 = v1 + v2 - v3
            vb(idx,4) = vb(idx,1) + vb(idx,2) - vb(idx,3);

            % ====== 1 side beam and 5th beam bad ====== %
            % This is the same calculation as above
            case id([1,5]) % beams 1 and 5 bad
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v1 = v3 + v4 - v2
            vb(idx,1) = vb(idx,3) + vb(idx,4) - vb(idx,2);

            case id([2,5]) % beams 2 and 5 bad
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v2 = v3 + v4 - v1
            vb(idx,2) = vb(idx,3) + vb(idx,4) - vb(idx,1);

            case id([3,5]) % beams 3 and 5 bad
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v3 = v1 + v2 - v4
            vb(idx,3) = vb(idx,1) + vb(idx,2) - vb(idx,4);

            case id([4,5]) % beams 4 and 5 bad
            % c*v1 + c*v2 = c*v3 + c*v4
            % ===>     v4 = v1 + v2 - v3
            vb(idx,4) = vb(idx,1) + vb(idx,2) - vb(idx,3);

            % ===== Beam 5 bad ===== %                            
            case id(5) % only beam 5 bad, set to average Z from beam pairs
            %     v5 = c/2*(v1+v2+v3+v4)
            vb(idx,5) = c/2*(vb(idx,1) + vb(idx,2) + vb(idx,3) + vb(idx,4));

            end
            
        end
    end
end
% Reshape beam velocity to original size and store in adcp struct
adcp.vel = permute(reshape(vb',nb,nt,nc), [3 1 2]);
