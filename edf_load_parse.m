clear all; clc; %close all

[f,p] = uigetfile("*.edf");
cd(p)

%%
skipAnnot = false;
[sFile, ChannelMat, ImportOptions] = in_fopen_edf([p,f],skipAnnot);
sfreq = sFile.prop.sfreq(1); % sampling frequency from header

%% times to samples
tform = "HH:mm:ss"; % string form for datetime conversion
starttime = sFile.header.starttime; % recording start time from edf header
dtstart = datetime(replace(starttime,".",":"),"InputFormat",tform,...
          "Format",tform); % reformated into matlab datetime

% dialog box for entering experiment start time
%%%% TO DO:
%%%% make this a function
prompt = {'Hour (HH; 24 hr format):','minutes (mm):','seconds (ss):'};
dlgtitle = 'Enter experiment start time';
fieldsize = [1 45; 1 45; 1 45];
definput = {'13','05','00'};
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
if ~unique(cellfun(@length,answer)) == 2
   error("Enter all values with two digits")
end

rstartstr = replace(join(string(answer'))," ",":");
recstart = datetime(rstartstr,"Format",tform); % tform formatted
% TO DO:
% assertions about string inputs

% dialog box for entering experiment end time
prompt = {'Hour (HH; 24 hr format):','minutes (mm):','seconds (ss):'};
dlgtitle = 'Enter experiment end time';
fieldsize = [1 45; 1 45; 1 45];
definput = {'13','05','00'};
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
if ~unique(cellfun(@length,answer)) == 2
   error("Enter all values with two digits")
end
rendstr = replace(join(string(answer'))," ",":");
recend = datetime(rendstr,"Format",tform); % tform formatted

% seconds between recording start time and header starttime
expstart = seconds(duration(recstart-dtstart,"Format","s")); % double
expend = seconds(duration(recend-dtstart,"Format","s")); % double
expdur = expend-expstart; % seconds

% convert duration to samples using header sampling rates
% ASSUMING ALL SAMPLING RATES ARE CONSTANT
% ASSUMING NO DROPPED SAMPLES (cannot confirm this and is assumed by edf anyway)
sampstart = expstart*sfreq;
sampend = expend*sfreq;

%% define other in_fread_edf inputs
SamplesBounds = [sampstart, sampend];

% define ChannelsRange and ChannelsSkip
answer = questdlg('Would you like to load a montage file?', ...
	              'Options', ...
	              'Yes','No','Yes');
% Handle response
switch answer
    case 'Yes'
        % load in a montage table
        % expected columns: clinical | number | analyze
        % clinical - signal name (e.g. LH1)
        % number - signal index
        % analyze - signal indices to keep
        [montf,montp] = uigetfile("*.csv;*.xlsx","Select montage file");
        fullmont = readtable([montp montf]);
        allchs = fullmont.number;
        keepchs = fullmont.analyze;
        montage = fullmont(ismember(montage.number,keepchs),...
                           ["clinical","number"]);
        montage = renamevars(montage,"number","channel");

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

%% load data into workspace
% TO DO:
% rewrite some of in_fread_edf to be more flexible with inputs
% (remove some assumptions in things like ChannelsRange, etc.)
ChannelsRange = [min(keepchs), max(keepchs)];
tic
% LOADING AS single INSTEAD OF double !!
data = in_fread_edf(sFile,SamplesBounds,ChannelsRange);
toc

%%
data = data(keepchs,:);

%% save as .MAT
% define ChannelsRange and ChannelsSkip
answer = questdlg('Would you like to save F as a .MAT file?', ...
	              'Options', ...
	              'Yes','No','Yes');
% Handle response
idflag = true;
switch answer
    case 'Yes'
        % string pattern for idstr (6 alphanumeric characters)
        pat = alphanumericsPattern(6,6);
        try
            idstr = string(montf(1:6));
        catch
            try
                idstr = string(p(end-6:end-1));
            catch
                idstr = input("Enter subjid:");
            end
        end
        
        % check and subjid string for saving
        while idflag
            prompt = "subjID = "+idstr+"?,  Y/N [Y]: ";
            txt = input(prompt,"s");
            if isempty(txt) | txt == "Y"
                idflag = false;
            else
                idstr = input("Enter subjid:");
            end
            % check that we have an idstr at this point and that it has 6 char
            if exist("idstr","var") && matches(idstr,pat)
                idflag = false;
            end
        end

        pdir = uigetdir("C:\Users\jmile3\Documents\MATLAB\converted_EDFs","Select save dir");
        mkdir(pdir,idstr)
        cd(pdir+"\"+idstr)
        % SAVING AS single INSTEAD OF double !!
        if exist("montage","var")
            save("raw_iEEG_"+idstr+".mat","data","montage","sfreq","-mat","-v7.3");
        else
            disp("Saving data without a montage file(!!)")
            save("raw_iEEG_"+idstr+".mat","data","sfreq","-mat","-v7.3");
        end
        disp("Done Saving")
    case 'No'
        disp("Not saving any data")
end
