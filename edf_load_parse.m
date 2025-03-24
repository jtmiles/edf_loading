
[f,p] = uigetfile("*.edf");
cd(p)

%%
skipAnnot = true; % keep this set to true unless you REALLY need annotations
% pretty sure it will load entire file in otherwise

[sFile, ChannelMat, ImportOptions] = in_fopen_edf([p,f],skipAnnot);
sfreq = sFile.prop.sfreq(1); % sampling frequency from header

%% trim file start and end times?
tform = "HH:mm:ss"; % string form for datetime conversion
starttime = sFile.header.starttime; % recording start time from edf header
dtstart = datetime(replace(starttime,".",":"),"InputFormat",tform,...
          "Format",tform); % reformated into matlab datetime
reclen = sFile.prop.times(2);
dtend = dtstart+seconds(reclen);

disp("Record start: "+string(dtstart))
disp("Record end: "+string(dtend))

% dialog box for entering experiment start time
prompt = {'Hour (HH; 24 hr format):','minutes (mm):','seconds (ss):'};
dlgtitle = 'Enter experiment start time';
recstart = time_dlg(prompt, dlgtitle, tform, dtstart);

% dialog box for entering experiment end time
recend = time_dlg(prompt, dlgtitle, tform, string(recstart+minutes(10)));

% seconds between recording start time and header starttime
expstart = seconds(duration(recstart-dtstart,"Format","s")); % double
expend = seconds(duration(recend-dtstart,"Format","s")); % double

% convert duration to samples using header sampling rates
% ASSUMING ALL SAMPLING RATES ARE CONSTANT
% ASSUMING NO DROPPED SAMPLES (cannot confirm this and is assumed by edf anyway)
sampstart = expstart*sfreq;
sampend = expend*sfreq;
SamplesBounds = [sampstart, sampend];

%% select subset of channels?
% define ChannelsRange and ChannelsSkip
answer = questdlg('Would you like to load all channels?', ...
	              'Options', ...
	              'Yes','No','Yes');
% Handle response
switch answer
    case 'Yes'
        keepchs = 1:sFile.header.nsignal;
    case 'No'
        prompt = {'Channel numbers:'};
        dlgtitle = 'Enter channels, separated by a space';
        fieldsize = [1 45];
        definput = {'1 2 3 4'};
        answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
        keepchs = str2double(split(answer," "));
        allchs = 1:max(keepchs);
end
keepchs = keepchs(~isnan(keepchs));
ChannelsRange = [min(keepchs), max(keepchs)];

%% load data into workspace
tic
data = in_fread_edf(sFile,SamplesBounds,ChannelsRange);
toc
data = data(keepchs,:);

%%
figure
plot(1/sfreq:1/sfreq:1,data(1,1:sfreq))
xlim([0 1])
title("First second of data from first channel loaded")

%%
function entertime = time_dlg(prompt, dlgtitle, tform, deftime)
fieldsize = [1 45; 1 45; 1 45];
tsplit = split(string(deftime),":");
answer = inputdlg(prompt,dlgtitle,fieldsize,tsplit);
if ~unique(cellfun(@length,answer)) == 2
    error("Enter all values with two digits")
end

rtstr = replace(join(string(answer'))," ",":");
entertime = datetime(rtstr,"Format",tform); % tform formatted
end