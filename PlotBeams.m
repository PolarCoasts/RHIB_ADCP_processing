function [fig,ax]=PlotBeams(adcp,var,vlim)

arguments
    adcp struct
    var string {mustBeMember(var,{'bvel','corr','echo'})}   %variable to plot
    vlim (1,2) double=[NaN NaN];                            %colorbar limits (defaults are set for each variable below)
end

% This function plots raw beam data
% 
% usage:
%   [fig,ax] = PlotBeams(adcp,var,vlim)
%
% var is the variable to be plotted ('bvel', 'corr', or 'echo')
% vlim is the limits for the colorbar
%   this input is optional as there are defaults set for each variable

if strcmp(var,'bvel')
    data=adcp.bvel;
    cmap=cmocean('balance');
    clabel='Beam Velocity (m/s)';
    if all(isnan(vlim))
        vlim=[-1 1];
    end
elseif strcmp(var,'corr')
    data=adcp.corr;
    cmap='parula';
    clabel='Correlation';
    if all(isnan(vlim))
        vlim=[64 128];
    end
elseif strcmp(var,'echo')
    data=adcp.echo_intens;
    cmap='parula';
    clabel='Echo Intensity';
    if all(isnan(vlim))
        vlim=[50 200];
    end
end

if isfield(adcp,'nuc_time')
    time=adcp.nuc_time;
else
    time=adcp.time;
end

n=adcp.config.n_beams;

xx=.06; yy=linspace(.08,.98,n+1);
ww=.88; hh=.9/n-.03;


fig=figure('Position',[10 10 1800 800]);
for i=1:n
    ax(i)=axes('Position',[xx yy(n+1-i) ww hh]);
    pcolorjw(time,adcp.cell_depth,squeeze(data(:,i,:)))
    axis ij
    colormap(cmap)
    clim(vlim)
    text(time(10),25,"Beam "+i,"FontSize",16,"BackgroundColor",'w')
    if i<n
        xticklabels([])
        if i==1
            title(string(datetime(time(1),'ConvertFrom','datenum')))
        end
    else
        cbar=colorbar('Position',[.95 .4 .008 .2],'FontSize',16);
        cbar.Label.String=clabel;
        xlabel('Time')
        datetick('x','keeplimits')
        yl=ylabel('Depth');
    end
    set(gca,'FontSize',16)
end
if n==5
    yspace=max(adcp.cell_depth,[],'omitnan')*1.8;
elseif n==4
    yspace=max(adcp.cell_depth,[],'omitnan')*1.3;
end
yl.Position(2)=-yspace;
linkaxes

