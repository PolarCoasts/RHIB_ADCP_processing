function adcp=nucRepair(adcp)
% there is a regularly occuring error that shows up in the nuc timestamps
% the vast majority of timestamps are correct, but occassionally the timestamp will be decades off 
% a timestamp is grabbed for each adcp ping, though, so the intervals between timestamps should be the same as between adcp pings after accounting for relative clock drift

if isempty(adcp)
    return
end

mean_nuc=mean(adcp.nuc_time,'omitnan');   % mean time gives a reference for time of deployment 
mean_diff=abs(adcp.nuc_time-ones(size(adcp.nuc_time))*mean_nuc); % difference between each timestamp and the mean time
idx=find(mean_diff>365);  % timestamps that are more than a year off of mean time
if ~isempty(idx)
    bi=idx-1; ai=idx+1;                 % indices before and after each bad timestamp
    idx_bounds=setdiff(sort([bi ai]),idx); % drop any indices that correspond to a bad timestamp (occurs when there are two in a row)
    b=intersect(bi,idx_bounds);         % indices of timestamps before and after each group of consecutive bad timestamps
    a=intersect(ai,idx_bounds);
    for i=1:length(b)
        mt=idx(idx>b(i) & idx<a(i));      % indices for consecutive bad timestamps
        pt=(adcp.time(mt)-adcp.time(b(i)))/(adcp.time(a(i))-adcp.time(b(i))); % proportion of time to each ping with bad nuc timestamp to total interval between adcp time with good nuc timestamps
        % time to each bad timestamp should have the same proportion to the total interval between good timestamps
        nuc_correct=pt*(adcp.nuc_time(a(i))-adcp.nuc_time(b(i)))+adcp.nuc_time(b(i));
        adcp.nuc_time(b(i)+1:a(i)-1)=nuc_correct;
    end
end
        
        
        
        