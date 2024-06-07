
function adcp=LocateBottom(adcp,options)

arguments
    adcp struct                         % structure containing adcp data
    options.minbs (1,1) double=10       % minimum backscatter value to consider as bottom signal
    options.gap (1,1) double=20         % number of timesteps between identified bottom signal to interpolate over
    options.binjump (1,1) double=5      % difference in depth bins between adjacent bottom signals at which a single point should be assumed erroneous
    options.meth char {mustBeMember(options.meth,{'spline','pchip','linear'})}="linear"
end

%if user enters 0 for binjump, assume they meant to allow for any magnitude of jump 
if options.binjump==0
    options.binjump=length(adcp.cell_depth);
end

sz=size(adcp.echo_intens);
depth=[adcp.cell_depth; 210]; %depth of 210 for times when no bottom is seen

% calculate backscatter from echo if not already done
if ~isfield(adcp,'backscatter')
    adcp=Echo2Backscatter(adcp);
end

% find peak gradient in backscatter
%   - this will miss bottom signals in bin 1 - will check for that below
bs=adcp.backscatter;
db=diff(bs);
[~,I]=max(db);

% find max backscatter near peak gradient
for j=1:sz(2)
    for k=1:sz(3)
        i=I(1,j,k);
        if isnan(i)
            i=sz(1);
        end
        bs(1:i,j,k)=NaN;
        bs(i+5:end,j,k)=NaN;
    end
end
[mbs,Ibs]=max(bs,[],'omitnan');
Ibs(isnan(mbs))=sz(1)+1;
Ibs(mbs<options.minbs)=sz(1)+1;

% check for bottom signal in bin 1
for j=1:sz(2)
    for k=2:sz(3)-1
        if Ibs(1,j,k)==sz(1)+1 && Ibs(1,j,k-1)<4 && adcp.backscatter(1,j,k)>=options.minbs
            Ibs(1,j,k)=1;
        elseif Ibs(1,j,k)==sz(1)+1 && Ibs(1,j,k+1)<4 && adcp.backscatter(1,j,k)>=options.minbs
            Ibs(1,j,k)=1;
        end
    end
end

% find depth of max backscatter
bot=squeeze(depth(Ibs));

% fill gaps
hw=floor(options.gap/2);
for j=1:sz(2)
    for k=hw+1:sz(3)-hw
        if bot(j,k)==210
            prev=find(bot(j,1:k)<210,1,'last');
            next=find(bot(j,k+1:end)<210,1,'first');
            len=k+next-prev;
            if ~isempty(prev) && ~isempty(next) && prev>2 && k+next+2<=sz(3)
                if k-prev+next-1<=options.gap
                    bot(j,prev-2:k+next+2)=interp1([1 2 3 len+(3:5)],[bot(j,prev-2:prev) bot(j,k+next:k+next+2)],1:len+5,options.meth);
                end
            end
        end
    end
end

% remove instances where bottom depth jumps a large distance and then comes back
dbot=diff(bot,1,2);
dbot(abs(dbot)<options.binjump*adcp.config.depth_cell_length)=0;
dsign=sign(dbot);
for j=1:sz(2)
    p=find(~dsign(j,:));
    dp=diff(p)-1;
    r=find(dp>1);
    start=p(r)+1;
    fin=p(r)+dp(r);
    for s=1:length(start)
        if abs(sum(dsign(j,start(s):fin(s))))<=1 && start(s)>2 && fin(s)+3<=sz(3)
            bot(j,start(s)-2:fin(s)+3)=interp1([1 2 3 dp(r(s))+(3:5)],bot(j,[start(s)-2:start(s) fin(s)+1:fin(s)+3]),1:dp(r(s))+5,options.meth);
        end
    end
end

% create mask from bottom depth
bot_mask=ones(sz);
for j=1:sz(2)
    for k=1:sz(3)
        bot_mask(depth>=bot(j,k),j,k)=NaN;
    end
end

adcp.bottom_depth=bot;
adcp.bottom_mask=bot_mask(1:sz(1),:,:);

adcp.BottomID.minimum_backscatter=options.minbs;
adcp.BottomID.identification_gap=options.gap;
adcp.BottomID.maximum_bins_between_consecutive=options.binjump;
adcp.BottomID.interp_method=options.meth;
adcp.BottomID.note="See LocateBottom for details on how bottom contours were identified";
