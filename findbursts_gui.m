function data = findbursts_gui(data, varargin)

opt.interburstdur = [];
opt.threshold = [];
opt.minspikes = [];
opt.quiet = false;

opt = parsevarargin(opt, varargin, 2);

if (~opt.quiet)
    fig = openfig(mfilename, 'new');
    gdata = guihandles(fig);
    set(gdata.prevButton,'Enable','off');
else
    gdata = struct;
end

nchan = size(data.sig,2);
gdata.chan = 1;
if (isempty(opt.threshold))
    gdata.thresh = 2*nanstd(data.sig);
else
    gdata.thresh = opt.threshold;
end
if (isempty(opt.interburstdur))
    gdata.interburst = 0.3*ones(1,nchan);
else
    gdata.interburst = opt.interburstdur;
end
if (isempty(opt.minspikes))
    gdata.minspikes = 2*ones(1,nchan);
else
    gdata.minspikes = opt.minspikes;
end
gdata.data = data;
gdata.hspikes = -1;
gdata.hbursts = -1;
gdata.hburstrate = -1;
gdata.data.spiket = cell(1,nchan);
gdata.data.spikeamp = cell(1,nchan);
gdata = update_spikes(gdata, true);

if (~opt.quiet)
    setUICallbacks(gdata);
    
    gdata = show_plot(gdata, 'all');
    guidata(fig,gdata);
    
    uiwait(fig);
    
    gdata = guidata(fig);
    if (ishandle(fig))
        delete(fig);
    end
    f = findobj('Tag','burstrate');
    if (~isempty(f))
        delete(f);
    end
end

data = gdata.data;
data.spikethreshold = gdata.thresh;

data.spiket = catuneven(2,data.spiket{:});
data.spikeamp = catuneven(2,data.spikeamp{:});
ctr1 = {data.burst.ctr};
ctr1 = cellfun(@(x) x', ctr1, 'UniformOutput',false);
data.burstt = catuneven(2,ctr1{:});

data.spikephase = NaN(size(data.spiket));
data.burstphase = NaN(size(data.burstt));
data.spikecyclet = NaN(size(data.spiket));
data.burstcyclet = NaN(size(data.burstt));
data.burstcycle = NaN(size(data.burstt));

uphase = unwrap(2*pi*data.phase) / (2*pi);
for i = 1:size(data.spiket,2)
    good = isfinite(data.spiket(:,i));
    data.spikephase(good,i) = interp1(data.t,uphase, data.spiket(good,i));

    cycle1 = floor(data.spikephase(good,i));
    data.spikecyclet(good,i) = interp1(uphase,data.t, cycle1);
    
    good = isfinite(data.burstt(:,i));
    data.burstphase(good,i) = interp1(data.t,uphase, data.burstt(good,i)); 
end

data.spikephase = mod(data.spikephase,1);
data.burstphase = mod(data.burstphase,1);

ct0 = data.t(1) - data.phase(1)/data.stimfreq;
ct1 = data.t(end)+1/data.stimfreq;
data.stimcyclet = (ct0:1/data.stimfreq:ct1)';

[data.burstspercycle,data.burstcycle] = histc(data.burstt,data.stimcyclet);
data.burstcycle(data.burstcycle == 0) = NaN;
good = isfinite(data.burstcycle);
data.burstcyclet = NaN(size(data.burstcycle));
data.burstcyclet(good) = data.stimcyclet(data.burstcycle(good));

if (~opt.quiet)
    ibdtxt = sprintf('%g ',gdata.interburst);
    thtxt = sprintf('%g ',gdata.thresh);
    mstxt = sprintf('%g ',gdata.minspikes);
    
    fprintf('%s = findbursts_gui(%s, ''threshold'', [%s], ''interburstdur'', [%s], ''minspikes'', [%s], ''quiet'')', ...
        inputname(1), inputname(1), thtxt(1:end-1), ibdtxt(1:end-1), mstxt(1:end-1));
end

%*************************************************************************
function gdata = show_plot(gdata, type)

if (ischar(type))
    type = {type};
end

c = gdata.chan;
ax = gdata.axes;
d = gdata.data;

if (any(ismember(type, {'all','plot'})))
    cla(ax,'reset');
    plot(ax, d.t,d.sig(:,c),'k-', 'HitTest','off');
    axis(ax, 'tight');

    xl = get(ax,'XLim');
    gdata.hthreshln = addplot(ax, xl,gdata.thresh([c c]),'g--', ...
        xl,-gdata.thresh([c c]),'g--', ...
        'ButtonDownFcn',@on_click_thresh_line);
    if (diff(xl) > 10)
        fac = diff(xl)/10;
        zoom(ax,'xon');
        zoom(ax,fac);
        zoom(ax,'off');
    end
end

if (any(ismember(type, {'all','spikes'})))
    if (ishandle(gdata.hspikes))
        delete(gdata.hspikes);
    end
    gdata.hspikes = addplot(ax, d.spiket{c},d.spikeamp{c}, 'ro', ...
        'MarkerFaceColor','r','MarkerSize',4,'HitTest','off');
end

if (any(ismember(type, {'all','bursts'})))
    if (ishandle(gdata.hbursts))
        delete(gdata.hbursts);
    end
    b = d.burst;
    
    on1 = b(c).on;
    off1 = b(c).off;
    ctr1 = b(c).ctr;
    
    yy = nanmean(abs(d.spikeamp{c}));
    
    h1 = addplot(ax, [on1; off1], repmat([yy; yy],[1 length(on1)]), 'b-', ...
        'LineWidth',2);
    gdata.hbursts = h1;
    
    if (ishandle(gdata.hburstrate))
        burstrate = 1./diff(ctr1);
        plot(gdata.hburstrate, ctr1(1:end-1),burstrate, 'ko');
        xlabel('Time (sec)');
        ylabel('Burst rate (Hz)');
    end
end

%*************************************************************************
function gdata = update_spikes(gdata, doall)

d = gdata.data;
if (doall)
    c = 1:size(d.sig,2);
else
    c = gdata.chan;
end

for i = c
    spikeind = findspikes(d.sig(:,i), gdata.thresh(i));
    d.spiket{i} = d.t(spikeind{1});
    d.spikeamp{i} = d.sig(spikeind{1},i);
end
gdata.data = d;
gdata = update_bursts(gdata, doall);

%*************************************************************************
function gdata = update_bursts(gdata, doall)

d = gdata.data;
if (doall)
    c = 1:size(d.sig,2);
else
    c = gdata.chan;
end

for i = c
    [burst1,spike1] = findbursts(d.spiket{i}, 'simple', 'interburstdur',gdata.interburst(i), ...
        'minspikes',gdata.minspikes(i));
    d.burst(i) = burst1;
end
gdata.data = d;

%*************************************************************************
function on_click_thresh_line(obj, event)

gdata = guidata(obj);
set(gdata.figure, 'WindowButtonMotionFcn',@on_drag_thresh_line, ...
    'WindowButtonUpFcn',@on_button_up_thresh_line);

%*************************************************************************
function on_drag_thresh_line(obj, event)

gdata = guidata(obj);

c = get(gdata.axes, 'CurrentPoint');
y = abs(c(1,2));
set(gdata.hthreshln(1), 'YData',[y y]);
set(gdata.hthreshln(2), 'YData',[-y -y]);

%*************************************************************************
function on_button_up_thresh_line(obj, event)

gdata = guidata(obj);

c = get(gdata.axes, 'CurrentPoint');
y = abs(c(1,2));
set(gdata.hthreshln(1), 'YData',[y y]);
set(gdata.hthreshln(2), 'YData',[-y -y]);

gdata.thresh(gdata.chan) = y;

set(gdata.spikeThreshEdit, 'String', num2str(y,3));

gdata = update_spikes(gdata, false);
gdata = show_plot(gdata, {'spikes','bursts'});

set(gdata.figure, 'WindowButtonMotionFcn',[], ...
    'WindowButtonUpFcn',[]);

guidata(obj,gdata);

%*************************************************************************
function on_set_chan(obj,event,dchan,chan)

gdata = guidata(obj);
chan0 = gdata.chan;

if (~isempty(chan))
    gdata.chan = chan;
else
    gdata.chan = gdata.chan + dchan;
end

nchan = size(gdata.data.sig,2);
if ((gdata.chan < 1) || (gdata.chan > nchan))
    gdata.chan = chan0;
else
    if (gdata.chan == nchan)
        set(gdata.nextButton,'Enable','off');
        set(gdata.prevButton,'Enable','on');
    elseif (gdata.chan == 1)
        set(gdata.nextButton,'Enable','on');
        set(gdata.prevButton,'Enable','off');
    else
        set(gdata.nextButton,'Enable','on');
        set(gdata.prevButton,'Enable','on');
    end
    
    gdata = show_plot(gdata,'all');
end
set(gdata.channelEdit, 'String', num2str(gdata.chan));
set(gdata.spikeThreshEdit, 'String', num2str(gdata.thresh(gdata.chan),3));
set(gdata.interburstDurEdit, 'String', num2str(gdata.interburst(gdata.chan),3));
set(gdata.minSpikesEdit, 'String', num2str(gdata.minspikes(gdata.chan),3));

guidata(obj,gdata);

%*************************************************************************
function on_edit_channel(obj,event)

gdata = guidata(obj);
s = get(obj,'String');
c = str2double(s);
guidata(obj,gdata);

on_set_chan(obj,event,[],c);

%*************************************************************************
function on_edit_spikeThresh(obj,event)

gdata = guidata(obj);
s = get(obj,'String');
c = str2double(s);

gdata.thresh(gdata.chan) = c;
gdata = update_spikes(gdata, false);
gdata = show_plot(gdata, {'spikes','bursts'});

guidata(obj,gdata);


%*************************************************************************
function on_edit_interburst(obj,event)

gdata = guidata(obj);
s = get(obj,'String');
c = str2double(s);

gdata.interburst(gdata.chan) = c;
gdata = update_bursts(gdata, false);
gdata = show_plot(gdata, 'bursts');

guidata(obj,gdata);


%*************************************************************************
function on_edit_minSpikes(obj,event)

gdata = guidata(obj);
s = get(obj,'String');
c = str2double(s);

gdata.minspikes(gdata.chan) = c;
gdata = update_bursts(gdata, false);
gdata = show_plot(gdata, 'bursts');

guidata(obj,gdata);

%*************************************************************************
function on_click_burstrate(obj,event)

gdata = guidata(obj);
if (get(obj, 'Value') > 0)
    pos = get(gdata.figure,'Position');
    pos(1) = pos(1) + pos(3);
    f = figure('Position',pos, 'Tag','burstrate', 'WindowStyle','normal');
    gdata.hburstrate = axes('Parent',f);
    
    show_plot(gdata,'bursts');
else
    f = findobj('Tag','burstrate');
    delete(f);
end
guidata(obj,gdata);

%*************************************************************************
function on_click_Done(obj,event)

data = guidata(obj);
uiresume(data.figure);

%*************************************************************************
function setUICallbacks(data)

set(data.doneButton,'Callback',@on_click_Done);
set(data.nextButton, 'Callback',{@on_set_chan,1,[]});
set(data.prevButton, 'Callback',{@on_set_chan,-1,[]});
set(data.channelEdit, 'Callback',@on_edit_channel);
set(data.spikeThreshEdit, 'Callback',@on_edit_spikeThresh);
set(data.interburstDurEdit, 'Callback',@on_edit_interburst);
set(data.minSpikesEdit, 'Callback',@on_edit_minSpikes);
set(data.burstRateCheck, 'Callback',@on_click_burstrate);






