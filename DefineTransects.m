function Xsect=DefineTransects(adcp,term) 

lon=adcp.vessel_lon;
lat=adcp.vessel_lat;
time=adcp.nuc_time;

% draw figure
fig=uifigure('Position',[10 10 1800 1000]);
ax=uiaxes(fig,'Position',[.05 .08 .65 .88],'Units','normalized');
ax.Position=[.05 .08 .65 .88];
st=scatter(ax,lon,lat,20,time,'filled');
hold(ax,'on')
cbar=colorbar(ax);
datetick(cbar,'y')

if ~isempty(term)
    plot(ax,term.lon,term.lat,'k','LineWidth',2)
end
drawnow

% add boxes to display endpoints
xl=.72*fig.Position(3); yl=.9*fig.Position(4);
wl=.12*fig.Position(3); hl=.03*fig.Position(4);

n=1; sp=[]; fp=[];

blab1=uilabel(fig,'Position',[xl yl+30 wl hl],'FontSize',16, 'Text','start');
blab2=uilabel(fig,'Position',[xl+250 yl+30 wl hl],'FontSize',16, 'Text','finish');
bx1(n)=uitextarea(fig,'Position',[xl yl wl hl]);
bx2(n)=uitextarea(fig,'Position',[xl+250 yl wl hl]);

fig.UserData=struct("start",bx1,"finish",bx2,'n',n);

% add function to record and display endpoints
st.ButtonDownFcn={@ClickLoc ax sp fp fig xl yl wl hl};

% add button to convert endpoints to transects and save
DoneButton=uibutton(fig,'Text','Save and Exit','Position',[.82*fig.Position(3) .04*fig.Position(4) wl hl],'FontSize',14,'ButtonPushedFcn',@(src,event) SaveExit(src,event,fig,st));


function ClickLoc(st,event,ax,sp,fp,fig,xl,yl,wl,hl)
    n=fig.UserData.n; 
    bx1=fig.UserData.start; 
    bx2=fig.UserData.finish;
    c=st.CData;
    x=st.XData;
    y=st.YData;
    pt=event.IntersectionPoint;
    [~,xi]=min(sqrt((pt(1)-x).^2+(pt(2)-y).^2));
    if isempty(bx1(n).Value{1})
        bx1(n).Value=string(c(xi)); 
        sp(n)=scatter(ax,x(xi),y(xi),50,'g','filled','MarkerEdgeColor','k');
        fig.UserData.start=bx1;
    else
        bx2(n).Value=string(c(xi)); 
        fp(n)=scatter(ax,x(xi),y(xi),50,'r','filled');
        linestart=str2double(bx1(n).Value);
        linefinish=str2double(bx2(n).Value);
        ii=find(c>=linestart & c<=linefinish);
        scatter(ax,x(ii),y(ii),20,[.8 .8 .8],'filled')
        clim(ax,[time(ii(end)) time(end)])
        n=n+1; yl=yl-40*(n-1);
        bx1(n)=uitextarea(fig,'Position',[xl yl wl hl]);
        bx2(n)=uitextarea(fig,'Position',[xl+250 yl wl hl]);
        fig.UserData.n=n;
        fig.UserData.start=bx1;
        fig.UserData.finish=bx2;
    end
end

function SaveExit(src,event,fig,st)
    n=fig.UserData.n;
    bx1=fig.UserData.start;
    if ~isempty(bx1(n).Value{1})
        fprintf('Please choose an end point for the current transect - then press "Save and Exit" \n');
        return
    else
        for i=1:n-1
            start=str2double(fig.UserData.start(i).Value{1});
            finish=str2double(fig.UserData.finish(i).Value{1});
            time=st.CData; 
            ii=find(time>=start & time<=finish);
            Xsect(i).starttime=start;
            Xsect(i).endtime=finish;
            Xsect(i).iX_ADCP=ii;
        end
    end
    close(fig)
end

waitfor(fig)
end

