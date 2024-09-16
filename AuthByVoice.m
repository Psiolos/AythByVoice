classdef AuthByVoice < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        AuthByVoiceUIFigure         matlab.ui.Figure
        TabGroup                    matlab.ui.container.TabGroup
        StartTab                    matlab.ui.container.Tab
        StartButton                 matlab.ui.control.Button
        TitleLabel                  matlab.ui.control.Label
        WelcomeLabel                matlab.ui.control.Label
        SelectModeTab               matlab.ui.container.Tab
        RecordLabel                 matlab.ui.control.Label
        RecordButton                matlab.ui.control.Button
        RegisterButton              matlab.ui.control.Button
        StartRecLabel               matlab.ui.control.Label
        EndRecLabel                 matlab.ui.control.Label
        RegisterLabel               matlab.ui.control.Label
        SelectButton                matlab.ui.control.Button
        SelectLabel                 matlab.ui.control.Label
        SelectModeExitButton        matlab.ui.control.Button
        PlayRecAuthTab              matlab.ui.container.Tab
        PlayLabel                   matlab.ui.control.Label
        StartAuthButton             matlab.ui.control.Button
        PlayButton                  matlab.ui.control.Button
        RepeatRecButton             matlab.ui.control.Button
        RepeatRecLabel              matlab.ui.control.Label
        StartAuthLabel              matlab.ui.control.Label
        WaitingTab                  matlab.ui.container.Tab
        WaitingLabel                matlab.ui.control.Label
        StartProcessButton          matlab.ui.control.Button
        SuccessTab                  matlab.ui.container.Tab
        SuccessRetryButton          matlab.ui.control.Button
        SuccessExitButton           matlab.ui.control.Button
        SuccessResultLabel          matlab.ui.control.Label
        SuccessResultLabel_2        matlab.ui.control.Label
        FailureTab                  matlab.ui.container.Tab
        FailureResultLabel          matlab.ui.control.Label
        FailureRetryButton          matlab.ui.control.Button
        FailureExitButton           matlab.ui.control.Button
        SlowWarningLabel            matlab.ui.control.Label
        FraudWarningLabel           matlab.ui.control.Label
        FailureResultLabel_2        matlab.ui.control.Label
        RegisterSignalsTab          matlab.ui.container.Tab
        RegisterSamplewLabel        matlab.ui.control.Label
        EntrySampleNameLabel        matlab.ui.control.Label
        Label_11                    matlab.ui.control.Label
        EntrySampleNameEditField    matlab.ui.control.EditField
        RegisterNextButton          matlab.ui.control.Button
        WarnForExistingFolderLabel  matlab.ui.control.Label
        RegisterYesButton           matlab.ui.control.Button
        RegisterNoButton            matlab.ui.control.Button
        ExitToStartButton           matlab.ui.control.Button
        MassRecPreparationTab       matlab.ui.container.Tab
        RegisterRecLabel            matlab.ui.control.Label
        RegisterStartRecButton      matlab.ui.control.Button
        Repeat20Label               matlab.ui.control.Label
        SlowAndClearLabel           matlab.ui.control.Label
        StartRecordLabel            matlab.ui.control.Label
        EndRecordLabel              matlab.ui.control.Label
        IncRefFileNumberLabel       matlab.ui.control.Label
        SelectVoiceFilesDB          matlab.ui.container.Tab
        SelectVoiceFilesLabel       matlab.ui.control.Label
        SelectVoiceFilesButton      matlab.ui.control.StateButton
        SelectVoiceFilesNextButton  matlab.ui.control.StateButton
        SelectVoiceDBFolderTab      matlab.ui.container.Tab
        SelectVoiceDBFolderLabel    matlab.ui.control.Label
        SelectVoiceDBFolderButton   matlab.ui.control.StateButton
        SelectVoiceDBNextButton     matlab.ui.control.StateButton
        ChangeVoiceDBFolderButton   matlab.ui.control.StateButton
        CheckMassRecTab             matlab.ui.container.Tab
        RegisterPlayRecButton       matlab.ui.control.Button
        RegisterRepeatRecButton     matlab.ui.control.Button
        RegisterAcceptRecButton     matlab.ui.control.Button
        CheckMassRecLabel           matlab.ui.control.Label
    end


    properties (Access = private)
        dbPath = {};            % user voice signals folders database path
        path = {};              % path of reference audiofiles
        dbFilenames = {};       % names of existing reference audiofiles
        tmpfilename = {};       % temp reference file
        samplename = {};        % sample file fullpath
        counter = 1;            % used for ref signals registration
        warnFlag  = {};         % used to display msg on autehtication failure
        newdir = {};            % dir name of a new person entry
        nSamples = 20;           % number of reference audio files per person
        keysSet = strings;      % to save person name
        valueSet = [];          % to save person pass threshold
        accessThreshold = 5;    % Granting access threshold
        warnThreshold = 15;     % Warning fraud threshold
        distanceArray           % Array to hold dtw distances
        updRefDataFlag = false  % Flag indicating to udpdate existing user data
    end

    methods (Access = private)
        % Load pass thresholds for already registered users
        function loadPassThresh(app)
            if ~isfile("keySet.mat") || ~isfile("valueSet.mat")
                warningMessage = sprintf('Warning: file does not exist:\n%s or \n%s', "keySet.mat","valueSet.mat");
                uiwait(msgbox(warningMessage));
                close all force;
            else
                k = load("keySet.mat");
                app.keysSet = k.keySet;
                v = load("valueSet.mat");
                app.valueSet = v.valSet;
            end
        end
        
        % Save pass threshold for a new registered user.
        function savePassThresh(app)
            keySet = app.keysSet;
            save("keySet.mat","keySet");
            valSet = app.valueSet;
            save("valueSet.mat","valSet");
        end

        function distMfccDtwCalculation(app, inputFile)
            dist_array = zeros(1,app.nSamples);
            % read sample input filename
            [y_orig,fs] = audioread(inputFile);
            
            % Apply specsub to clean signal from background noise
            y = specsub(y_orig,fs);
            
            % Bring clean signal to zero seconds
            ymax = movmax(y,175);
            yclipped = y(ymax>0.01);
                        
            % Set window length and overlapping
            winLen = round(0.02*fs); 
            overlap = round(0.013*fs); 
            
            % Apply Mel Frequency Cepstrum to signal and calculate MFCC coefficients
            coeffs_y = mfcc(yclipped,fs,"WindowLength",winLen, "OverlapLength",overlap,"LogEnergy","Ignore");
            
            % Apply standardization and get final signal for comparison
            z_coeffs_y = zscore(coeffs_y);
            
            % Same procedure for the reference files for steps audioread to standardization
            for j=1:app.nSamples
                fileref = fullfile(app.path, app.dbFilenames{j});
                [x_orig,fs] = audioread(fileref);   % read audio
                x = specsub(x_orig,fs);             % apply specsub
                xmax = movmax(x,175);               % Bringn to zero
                xclipped = x(xmax>0.01);
                % Apply mfcc and standardization
                coeffs_x = mfcc(xclipped,fs,"WindowLength",winLen,"OverlapLength",overlap,"LogEnergy","Ignore");
                z_coeffs_x = zscore(coeffs_x);
                % Apply DTW to calculate distance for each comparison
                [dist_array(j),indColz,indRowz,Dmatrixz,kz] = DynamicTimeWarping(z_coeffs_x,z_coeffs_y);
                app.distanceArray = dist_array;
            end
        end
    end

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            clc;
            clearvars; 
            close all; 
            warning off;
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            % Load pass thresholds values and go to Selection Tab
            loadPassThresh(app);
            app.TabGroup.SelectedTab = app.SelectVoiceDBFolderTab;
        end

        % Button pushed function: StartAuthButton
        function StartAuthButtonPushed(app, event)
            app.TabGroup.SelectedTab = app.SelectVoiceFilesDB;
        end

        % Button pushed function: RecordButton
        function RecordButtonPushed(app, event)
            % Set features and duration of signal to be recorded
            Fs=44100;
            ch=1;
            datatype='uint8';
            nbits=16;
            duration=3; %time in seconds
            % Set device for recording
            recorder=audiorecorder(Fs,nbits,ch);
            app.StartRecLabel.Visible = 'on';
            recordblocking(recorder,duration);
            app.StartRecLabel.Visible = 'off';
            app.EndRecLabel.Visible = 'on';
            %Save recorde audio signal
            x=getaudiodata(recorder,datatype);
            % Create new audio file
            app.samplename = fullfile(app.dbPath,'sample.wav');
            audiowrite(app.samplename,x,Fs);
            app.EndRecLabel.Visible = 'off';
            pause(1);
            app.TabGroup.SelectedTab = app.PlayRecAuthTab;
        end

        % Button pushed function: FailureExitButton
        function FailureExitButtonPushed(app, event)
            app.StartProcessButton.Visible = 'on';
            clearvars; close all force ;
        end

        % Button pushed function: RegisterButton
        function RegisterButtonPushed(app, event)
            app.TabGroup.SelectedTab = app.RegisterSignalsTab;
        end

        % Callback function
        function ExitButtonSuccessPushed(app, event)
            close all force ;
        end

        % Button pushed function: FailureRetryButton
        function FailureRetryButtonPushed(app, event)
            if app.warnFlag == "slow"
                app.SlowWarningLabel.Visible = 'off';
            elseif app.warnFlag == "fraud"
                app.FraudWarningLabel.Visible = 'off';
            end
            app.StartProcessButton.Visible = 'on';
            app.TabGroup.SelectedTab = app.SelectModeTab;
            %clearvars;
        end

        % Selection change function: TabGroup
        function StartGUI(app, event)

        end

        % Button pushed function: RepeatRecButton
        function RepeatRecButtonPushed(app, event)
            app.TabGroup.SelectedTab = app.SelectModeTab;
        end

        % Button pushed function: PlayButton
        function PlayButtonPushed(app, event)
            % Play the recorded file 
            sample = app.samplename;
            [y,fs1] = audioread(sample);
            x = specsub(y,fs1);
            sound(x,fs1);     
        end

        % Button pushed function: RegisterNextButton
        function RegisterNextButtonPushed(app, event)
            if ~isempty(app.EntrySampleNameEditField.Value)
                app.newdir = fullfile(app.dbPath,app.EntrySampleNameEditField.Value);
                % If there is no folder with name entered create it
                if ~exist(app.newdir, 'dir')
                    app.updRefDataFlag = false;
                    mkdir(app.newdir)
                    app.keysSet(end+1) = app.EntrySampleNameEditField.Value;
                    app.TabGroup.SelectedTab = app.MassRecPreparationTab;
                % If there is already, warn user
                else
                    app.updRefDataFlag = true;
                    app.WarnForExistingFolderLabel.Visible = 'on';
                    app.RegisterYesButton.Visible = 'on';
                    app.RegisterNoButton.Visible = 'on';
                end
            end           
        end

        % Value changed function: SelectVoiceFilesButton
        function SelectVoiceFilesButtonValueChanged(app, event)
            % Select folder of person to be authenticated
            app.SelectVoiceFilesButton.Value;
            app.path = uigetdir(app.dbPath, 'Select a folder');
            drawnow;
            figure(app.AuthByVoiceUIFigure);
            files = dir(fullfile(app.path, '*.wav'));
            T = struct2table(files);
            app.dbFilenames = T{:,1}';
            app.SelectVoiceFilesNextButton.Visible = 'on';
        end

        % Button pushed function: SuccessRetryButton
        function SuccessRetryButtonPushed(app, event)
            app.TabGroup.SelectedTab = app.SelectModeTab;
            %clearvars;
        end

        % Button pushed function: SuccessExitButton
        function SuccessExitButtonPushed(app, event)
            clearvars; close all force;
        end

        % Value changed function: SelectVoiceDBFolderButton
        function SelectVoiceDBFolderButtonValueChanged(app, event)
            % Select main voice data folder which contains voice data subfolders
            % and sample.wav is stored
            app.SelectVoiceDBFolderButton.Value;
            app.dbPath = uigetdir;
            drawnow;
            figure(app.AuthByVoiceUIFigure);
            app.SelectVoiceDBFolderButton.Visible = 'off';
            app.ChangeVoiceDBFolderButton.Visible = 'on';
            app.SelectVoiceDBNextButton.Visible = 'on';
        end

        % Value changed function: SelectVoiceDBNextButton
        function SelectVoiceDBNextButtonValueChanged(app, event)
            app.SelectVoiceDBNextButton.Value;            
            app.TabGroup.SelectedTab = app.SelectModeTab;
            app.SelectVoiceDBFolderButton.Visible = 'on';
            app.ChangeVoiceDBFolderButton.Visible = 'off';
            app.SelectVoiceDBNextButton.Visible = 'off';
        end

        % Value changed function: ChangeVoiceDBFolderButton
        function ChangeVoiceDBFolderButtonValueChanged(app, event)
            app.ChangeVoiceDBFolderButton.Value;
            app.dbPath = uigetdir;
            drawnow;
            figure(app.AuthByVoiceUIFigure);
        end

        % Value changed function: SelectVoiceFilesNextButton
        function SelectVoiceFilesNextButtonValueChanged(app, event)
            app.SelectVoiceFilesNextButton.Value;
            app.TabGroup.SelectedTab = app.WaitingTab;
            app.SelectVoiceFilesNextButton.Visible = 'off';
        end

        % Button pushed function: StartProcessButton
        function StartAuthProcess(app, event)
            % Main part of the application
            app.StartProcessButton.Visible = 'off';
            app.WaitingLabel.Visible = 'on';
            % Get latest pass-threshold values 
            keySetToCell = cellstr(app.keysSet);
            valueSetToCell = num2cell(app.valueSet);
            % Create a container to hold pairs of values user->pass-threshold
            PT = containers.Map(keySetToCell,valueSetToCell);
            % Init array to hold the distances between sample file and reference files
%             noOfBaseFiles = length(app.dbFilenames);
%             dist_array = zeros(1,noOfBaseFiles);
            
            %Initiate pass-reject array to empty strings
            pass_rej_array = strings(1,app.nSamples);
            
            % Get pass threshold value from PT container for person to be checked
            selected_path = regexp(app.path,'\','split');   %strip path string
            person_to_check = char(selected_path(length(selected_path))); % isolate last dir
            pass_thresh = PT(person_to_check);
            
            % Set thresholds values and read sample signal
            grant_thresh = app.accessThreshold;
            warning_thresh = app.warnThreshold;
            
            % Calculate distances
            distMfccDtwCalculation(app, app.samplename);

            % If distance is less than threshold set state = pass
            for j = 1:app.nSamples
                if app.distanceArray(j) < pass_thresh
                    pass_rej_array(j) = "pass";
                %else state = reject
                else
                    pass_rej_array(j) = "reject";
                end
            end
            % If rejects are more than pass-threshold access denied
            reject_count = numel(find(pass_rej_array=="reject"));
            if  reject_count > grant_thresh
                % rejects less than warn threshold, just warn 
                if numel(find(pass_rej_array=="reject")) < warning_thresh
                    app.SlowWarningLabel.Visible = 'on';
                    app.warnFlag = "slow";
                else
                    % else Alert
                    app.FraudWarningLabel.Visible = 'on';
                    app.warnFlag = "fraud";
                end
                app.TabGroup.SelectedTab = app.FailureTab;
                
            else % else access granted
                app.TabGroup.SelectedTab = app.SuccessTab;
            end
            
            app.StartProcessButton.Visible = 'on';
            app.WaitingLabel.Visible = 'off';
        end

        % Button pushed function: SelectButton
        function SelectButtonPushed(app, event)
            % Open modal and choose a file for authentication 
            [sample,selpath] = uigetfile('*.wav');
            app.samplename = fullfile(selpath,sample);
            drawnow;
            figure(app.AuthByVoiceUIFigure);
            app.TabGroup.SelectedTab = app.PlayRecAuthTab;
        end

        % Button pushed function: RegisterYesButton
        function RegisterYesButtonPushed(app, event)
            % Continue to record new reference files for existing user
            app.TabGroup.SelectedTab = app.MassRecPreparationTab;
            app.WarnForExistingFolderLabel.Visible = 'off';
            app.RegisterYesButton.Visible = 'off';
            app.RegisterNoButton.Visible = 'off';
        end

        % Button pushed function: RegisterNoButton
        function RegisterNoButtonPushed(app, event)
            app.WarnForExistingFolderLabel.Visible = 'off';
            app.RegisterYesButton.Visible = 'off';
            app.RegisterNoButton.Visible = 'off';           
        end

        % Button pushed function: ExitToStartButton
        function ExitToStartButtonPushed(app, event)
            app.WarnForExistingFolderLabel.Visible = 'off';
            app.RegisterYesButton.Visible = 'off';
            app.RegisterNoButton.Visible = 'off';
            app.ExitToStartButton.Visible = 'off';
            app.TabGroup.SelectedTab = app.SelectModeTab;
        end

        % Button pushed function: RegisterStartRecButton
        function RegisterStartRecButtonPushed(app, event)
            % Get new reference file and update counter
            Fs=44100; ch=1; datatype='uint8'; nbits=16;
            duration=3; %time in seconds
            app.newdir = app.EntrySampleNameEditField.Value;
            if app.counter < 10
                filend=sprintf('samplRef0%d.wav', app. counter);
            else
                filend=sprintf('samplRef%d.wav', app.counter);
            end
            app.IncRefFileNumberLabel.Visible = 'on'; 
            app.IncRefFileNumberLabel.Text = filend;
            recorder=audiorecorder(Fs,nbits,ch);
            app.StartRecordLabel.Visible = 'on';
            recordblocking(recorder,duration);
            app.StartRecordLabel.Visible = 'off';
            app.EndRecordLabel.Visible = 'on';
            %Save recorde audio signal
            x=getaudiodata(recorder,datatype);
            %Create new audio file
            app.tmpfilename = fullfile(app.dbPath,app.newdir,filend);
            audiowrite(app.tmpfilename,x,Fs);
            pause(1);
            app.EndRecordLabel.Visible = 'off';
            app.IncRefFileNumberLabel.Visible = 'off'; 
            app.TabGroup.SelectedTab = app.CheckMassRecTab;
        end

        % Button pushed function: RegisterPlayRecButton
        function RegisterPlayRecButtonPushed(app, event)
            % Play a recorder reference file before accept it
            sample = app.tmpfilename;
            [y,fs1] = audioread(sample);
            x = specsub(y,fs1);
            sound(x,fs1); 
        end

        % Button pushed function: RegisterRepeatRecButton
        function RegisterRepeatRecButtonPushed(app, event)
            app.TabGroup.SelectedTab = app.MassRecPreparationTab;
        end

        % Button pushed function: RegisterAcceptRecButton
        function RegisterAcceptRecButtonPushed(app, event)
            % Keep accepting samples untill counter reaches defined number
            app.counter = app.counter + 1;
            if app.counter <= app.nSamples
                app.TabGroup.SelectedTab = app.MassRecPreparationTab;
            % When done calculate the pass-threshold value for new person's reference set
            else
                % reset counter
                app.counter = 1;
                app.CheckMassRecLabel.Text = 'Η καταχώρηση των δειγμάτων ολοκληρώθηκε με επιτυχία';
                app.RegisterPlayRecButton.Visible = 'off';
                app.RegisterRepeatRecButton.Visible = 'off';
                app.RegisterAcceptRecButton.Visible = 'off';
                app.CheckMassRecLabel.Text = 'Αναμονή για ρυθμίσεις παραμέτρων...';
                pause(1);
                
%                 dist_array = zeros(1,app.nSamples);
                dist_array_tot = zeros(app.nSamples,app.nSamples);
                app.path = uigetdir(pwd, 'Select a folder');
                drawnow;
                figure(app.AuthByVoiceUIFigure);
                files = dir(fullfile(app.path,'*.wav'));
                T = struct2table(files);
                app.dbFilenames = T{:,1}';
                for k=1:app.nSamples
                    fileinput = fullfile(app.path, app.dbFilenames{k});
                    
                    % Calculate distances between k-th sample and all reference signals
                    distMfccDtwCalculation(app, fileinput);
                    % Store distances of each input sample and refrence signals
                    dist_array_tot(k,:) = app.distanceArray;
                end
                if ~app.updRefDataFlag
                    app.valueSet(end+1) = min(max(dist_array_tot));
                else
                    % strip path string to get dir name
                    selected_path = regexp(app.path,'\','split');   
                    person_to_update = char(selected_path(length(selected_path))); % isolate last dir used
                    % find index in names array
                    index = find(app.keysSet == person_to_update);
                    % use index to update pass-threshold value
                    app.valueSet(index) = min(max(dist_array_tot));
                    app.updRefDataFlag = false;
                end
                savePassThresh(app);
                loadPassThresh(app);
                app.TabGroup.SelectedTab = app.SelectModeTab;
                app.RegisterPlayRecButton.Visible = 'on';
                app.RegisterRepeatRecButton.Visible = 'on';
                app.RegisterAcceptRecButton.Visible = 'on';
                
            end
        end

        % Button pushed function: SelectModeExitButton
        function SelectModeExitButtonPushed(app, event)
            close all force;
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create AuthByVoiceUIFigure
            app.AuthByVoiceUIFigure = uifigure;
            app.AuthByVoiceUIFigure.Color = [0 0 1];
            app.AuthByVoiceUIFigure.Position = [300 150 640 480];
            app.AuthByVoiceUIFigure.Name = 'AuthByVoice';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.AuthByVoiceUIFigure);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @StartGUI, true);
            app.TabGroup.Position = [1 1 640 505];

            % Create StartTab
            app.StartTab = uitab(app.TabGroup);
            app.StartTab.Title = 'Tab';
            app.StartTab.BackgroundColor = [0.549 0.749 0.851];

            % Create StartButton
            app.StartButton = uibutton(app.StartTab, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.StartButton.FontSize = 14;
            app.StartButton.Position = [270 228 100 24];
            app.StartButton.Text = 'Έναρξη';

            % Create TitleLabel
            app.TitleLabel = uilabel(app.StartTab);
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.Position = [96 400 447 30];
            app.TitleLabel.Text = 'Ταυτοποίηση μέσω Αναγνώρισης Φωνής';

            % Create WelcomeLabel
            app.WelcomeLabel = uilabel(app.StartTab);
            app.WelcomeLabel.FontSize = 14;
            app.WelcomeLabel.Position = [107 301 425 22];
            app.WelcomeLabel.Text = 'Καλώς ήρθατε στην εφαρμογή. Πατήστε Έναρξη για να ξεκινήσετε.';

            % Create SelectModeTab
            app.SelectModeTab = uitab(app.TabGroup);
            app.SelectModeTab.Title = 'Tab2';
            app.SelectModeTab.BackgroundColor = [0.549 0.749 0.851];

            % Create RecordLabel
            app.RecordLabel = uilabel(app.SelectModeTab);
            app.RecordLabel.HorizontalAlignment = 'center';
            app.RecordLabel.FontSize = 14;
            app.RecordLabel.Position = [170 378 299 22];
            app.RecordLabel.Text = 'Για ταυτοποίηση προσώπου πατήστε Εγγραφή';

            % Create RecordButton
            app.RecordButton = uibutton(app.SelectModeTab, 'push');
            app.RecordButton.ButtonPushedFcn = createCallbackFcn(app, @RecordButtonPushed, true);
            app.RecordButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RecordButton.FontSize = 14;
            app.RecordButton.Position = [114 215 100 24];
            app.RecordButton.Text = 'Εγγραφή';

            % Create RegisterButton
            app.RegisterButton = uibutton(app.SelectModeTab, 'push');
            app.RegisterButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterButtonPushed, true);
            app.RegisterButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterButton.FontSize = 14;
            app.RegisterButton.Position = [427 215 100 24];
            app.RegisterButton.Text = 'Καταχώρηση';

            % Create StartRecLabel
            app.StartRecLabel = uilabel(app.SelectModeTab);
            app.StartRecLabel.FontName = 'Verdana';
            app.StartRecLabel.FontWeight = 'bold';
            app.StartRecLabel.FontColor = [1 0 0];
            app.StartRecLabel.Visible = 'off';
            app.StartRecLabel.Position = [137 177 64 22];
            app.StartRecLabel.Text = 'Start rec';

            % Create EndRecLabel
            app.EndRecLabel = uilabel(app.SelectModeTab);
            app.EndRecLabel.FontName = 'Verdana';
            app.EndRecLabel.FontWeight = 'bold';
            app.EndRecLabel.FontColor = [1 0 0];
            app.EndRecLabel.Visible = 'off';
            app.EndRecLabel.Position = [137 137 59 22];
            app.EndRecLabel.Text = 'End Rec';

            % Create RegisterLabel
            app.RegisterLabel = uilabel(app.SelectModeTab);
            app.RegisterLabel.HorizontalAlignment = 'center';
            app.RegisterLabel.FontSize = 14;
            app.RegisterLabel.Position = [130 284 380 22];
            app.RegisterLabel.Text = 'Για εισαγωγή νέων δειγμάτων φωνής πατήστε Καταχώρηση';

            % Create SelectButton
            app.SelectButton = uibutton(app.SelectModeTab, 'push');
            app.SelectButton.ButtonPushedFcn = createCallbackFcn(app, @SelectButtonPushed, true);
            app.SelectButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SelectButton.FontSize = 14;
            app.SelectButton.Position = [270 215 100 24];
            app.SelectButton.Text = 'Επιλογή';

            % Create SelectLabel
            app.SelectLabel = uilabel(app.SelectModeTab);
            app.SelectLabel.HorizontalAlignment = 'center';
            app.SelectLabel.FontSize = 14;
            app.SelectLabel.Position = [172 332 295 22];
            app.SelectLabel.Text = 'Για ταυτοποίηση από αρχείο πατήστε Επιλογή';

            % Create SelectModeExitButton
            app.SelectModeExitButton = uibutton(app.SelectModeTab, 'push');
            app.SelectModeExitButton.ButtonPushedFcn = createCallbackFcn(app, @SelectModeExitButtonPushed, true);
            app.SelectModeExitButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SelectModeExitButton.FontSize = 14;
            app.SelectModeExitButton.Position = [270 123 100 24];
            app.SelectModeExitButton.Text = 'Έξοδος';

            % Create PlayRecAuthTab
            app.PlayRecAuthTab = uitab(app.TabGroup);
            app.PlayRecAuthTab.Title = 'Tab3';
            app.PlayRecAuthTab.BackgroundColor = [0.549 0.749 0.851];

            % Create PlayLabel
            app.PlayLabel = uilabel(app.PlayRecAuthTab);
            app.PlayLabel.FontSize = 14;
            app.PlayLabel.Position = [158 378 319 22];
            app.PlayLabel.Text = 'Πατήστε Αναπαραγωγή για να ακούσετε το αρχείο';

            % Create StartAuthButton
            app.StartAuthButton = uibutton(app.PlayRecAuthTab, 'push');
            app.StartAuthButton.ButtonPushedFcn = createCallbackFcn(app, @StartAuthButtonPushed, true);
            app.StartAuthButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.StartAuthButton.FontSize = 14;
            app.StartAuthButton.Position = [418 219 100 24];
            app.StartAuthButton.Text = 'Έλεγχος';

            % Create PlayButton
            app.PlayButton = uibutton(app.PlayRecAuthTab, 'push');
            app.PlayButton.ButtonPushedFcn = createCallbackFcn(app, @PlayButtonPushed, true);
            app.PlayButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.PlayButton.FontSize = 14;
            app.PlayButton.Position = [111 219 106 24];
            app.PlayButton.Text = 'Αναπαραγωγή';

            % Create RepeatRecButton
            app.RepeatRecButton = uibutton(app.PlayRecAuthTab, 'push');
            app.RepeatRecButton.ButtonPushedFcn = createCallbackFcn(app, @RepeatRecButtonPushed, true);
            app.RepeatRecButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RepeatRecButton.FontSize = 14;
            app.RepeatRecButton.Position = [270 138 100 24];
            app.RepeatRecButton.Text = 'Επιστροφή';

            % Create RepeatRecLabel
            app.RepeatRecLabel = uilabel(app.PlayRecAuthTab);
            app.RepeatRecLabel.FontSize = 14;
            app.RepeatRecLabel.Position = [145 301 346 22];
            app.RepeatRecLabel.Text = 'Πατήστε Επιστροφή για να γράψετε καινούργιο αρχείο';

            % Create StartAuthLabel
            app.StartAuthLabel = uilabel(app.PlayRecAuthTab);
            app.StartAuthLabel.FontSize = 14;
            app.StartAuthLabel.Position = [163 340 313 22];
            app.StartAuthLabel.Text = 'Πατήστε Έλεγχος για να ξεκινήσει η ταυτοποιήση';

            % Create WaitingTab
            app.WaitingTab = uitab(app.TabGroup);
            app.WaitingTab.Title = 'Tab4';
            app.WaitingTab.BackgroundColor = [0.549 0.749 0.851];

            % Create WaitingLabel
            app.WaitingLabel = uilabel(app.WaitingTab);
            app.WaitingLabel.FontSize = 14;
            app.WaitingLabel.Visible = 'off';
            app.WaitingLabel.Position = [114 312 411 22];
            app.WaitingLabel.Text = 'Περιμένετε μέχρι να ολοκληρωθεί ο έλεγχος για την ταυτοποιήση';

            % Create StartProcessButton
            app.StartProcessButton = uibutton(app.WaitingTab, 'push');
            app.StartProcessButton.ButtonPushedFcn = createCallbackFcn(app, @StartAuthProcess, true);
            app.StartProcessButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.StartProcessButton.FontSize = 14;
            app.StartProcessButton.Position = [243 240 153 24];
            app.StartProcessButton.Text = 'Έναρξη ταυτοποίησης';

            % Create SuccessTab
            app.SuccessTab = uitab(app.TabGroup);
            app.SuccessTab.Title = 'Tab5';
            app.SuccessTab.BackgroundColor = [0.549 0.749 0.851];

            % Create SuccessRetryButton
            app.SuccessRetryButton = uibutton(app.SuccessTab, 'push');
            app.SuccessRetryButton.ButtonPushedFcn = createCallbackFcn(app, @SuccessRetryButtonPushed, true);
            app.SuccessRetryButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SuccessRetryButton.FontSize = 14;
            app.SuccessRetryButton.Position = [153 240 112 24];
            app.SuccessRetryButton.Text = 'Δοκιμάστε ξανά';

            % Create SuccessExitButton
            app.SuccessExitButton = uibutton(app.SuccessTab, 'push');
            app.SuccessExitButton.ButtonPushedFcn = createCallbackFcn(app, @SuccessExitButtonPushed, true);
            app.SuccessExitButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SuccessExitButton.FontSize = 14;
            app.SuccessExitButton.Position = [377 240 100 24];
            app.SuccessExitButton.Text = 'Έξοδος';

            % Create SuccessResultLabel
            app.SuccessResultLabel = uilabel(app.SuccessTab);
            app.SuccessResultLabel.HorizontalAlignment = 'center';
            app.SuccessResultLabel.FontSize = 14;
            app.SuccessResultLabel.Position = [205 357 149 22];
            app.SuccessResultLabel.Text = 'Έλεγχος ταυτοποιήσης:';

            % Create SuccessResultLabel_2
            app.SuccessResultLabel_2 = uilabel(app.SuccessTab);
            app.SuccessResultLabel_2.HorizontalAlignment = 'center';
            app.SuccessResultLabel_2.FontSize = 14;
            app.SuccessResultLabel_2.FontWeight = 'bold';
            app.SuccessResultLabel_2.FontColor = [0.102 0.651 0.102];
            app.SuccessResultLabel_2.Position = [353 357 82 22];
            app.SuccessResultLabel_2.Text = 'ΘΕΤΙΚΟΣ';

            % Create FailureTab
            app.FailureTab = uitab(app.TabGroup);
            app.FailureTab.Title = 'Tab6';
            app.FailureTab.BackgroundColor = [0.549 0.749 0.851];

            % Create FailureResultLabel
            app.FailureResultLabel = uilabel(app.FailureTab);
            app.FailureResultLabel.HorizontalAlignment = 'center';
            app.FailureResultLabel.FontSize = 14;
            app.FailureResultLabel.Position = [203 357 156 22];
            app.FailureResultLabel.Text = 'Έλεγχος ταυτοποιήσης: ';

            % Create FailureRetryButton
            app.FailureRetryButton = uibutton(app.FailureTab, 'push');
            app.FailureRetryButton.ButtonPushedFcn = createCallbackFcn(app, @FailureRetryButtonPushed, true);
            app.FailureRetryButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.FailureRetryButton.FontSize = 14;
            app.FailureRetryButton.Position = [152 240 112 24];
            app.FailureRetryButton.Text = 'Δοκιμάστε ξανά';

            % Create FailureExitButton
            app.FailureExitButton = uibutton(app.FailureTab, 'push');
            app.FailureExitButton.ButtonPushedFcn = createCallbackFcn(app, @FailureExitButtonPushed, true);
            app.FailureExitButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.FailureExitButton.FontSize = 14;
            app.FailureExitButton.Position = [375 240 100 24];
            app.FailureExitButton.Text = 'Έξοδος';

            % Create SlowWarningLabel
            app.SlowWarningLabel = uilabel(app.FailureTab);
            app.SlowWarningLabel.FontSize = 14;
            app.SlowWarningLabel.FontWeight = 'bold';
            app.SlowWarningLabel.FontColor = [0.851 0.3294 0.102];
            app.SlowWarningLabel.Visible = 'off';
            app.SlowWarningLabel.Position = [146 316 348 22];
            app.SlowWarningLabel.Text = 'Προσπαθήστε ξανά. Μιλήστε πιο αργά και καθαρά.';

            % Create FraudWarningLabel
            app.FraudWarningLabel = uilabel(app.FailureTab);
            app.FraudWarningLabel.FontSize = 14;
            app.FraudWarningLabel.FontWeight = 'bold';
            app.FraudWarningLabel.FontColor = [1 0 0];
            app.FraudWarningLabel.Visible = 'off';
            app.FraudWarningLabel.Position = [143 316 354 22];
            app.FraudWarningLabel.Text = 'Προσοχή! Πολύ πιθανό να είναι διαφορετικό άτομο.';

            % Create FailureResultLabel_2
            app.FailureResultLabel_2 = uilabel(app.FailureTab);
            app.FailureResultLabel_2.HorizontalAlignment = 'center';
            app.FailureResultLabel_2.FontSize = 14;
            app.FailureResultLabel_2.FontWeight = 'bold';
            app.FailureResultLabel_2.FontColor = [1 0 0];
            app.FailureResultLabel_2.Position = [358 357 96 22];
            app.FailureResultLabel_2.Text = 'ΑΡΝΗΤΙΚΟΣ';

            % Create RegisterSignalsTab
            app.RegisterSignalsTab = uitab(app.TabGroup);
            app.RegisterSignalsTab.Title = 'Tab7';
            app.RegisterSignalsTab.BackgroundColor = [0.549 0.749 0.851];

            % Create RegisterSamplewLabel
            app.RegisterSamplewLabel = uilabel(app.RegisterSignalsTab);
            app.RegisterSamplewLabel.HorizontalAlignment = 'center';
            app.RegisterSamplewLabel.FontSize = 20;
            app.RegisterSamplewLabel.FontWeight = 'bold';
            app.RegisterSamplewLabel.Position = [208 411 224 24];
            app.RegisterSamplewLabel.Text = 'Καταχώρηση Σημάτων';

            % Create EntrySampleNameLabel
            app.EntrySampleNameLabel = uilabel(app.RegisterSignalsTab);
            app.EntrySampleNameLabel.FontSize = 14;
            app.EntrySampleNameLabel.Position = [135 348 369 22];
            app.EntrySampleNameLabel.Text = 'Εισάγετε το επίθετό σας με πεζούς λατινικούς χαρακτήρες';

            % Create Label_11
            app.Label_11 = uilabel(app.RegisterSignalsTab);
            app.Label_11.HorizontalAlignment = 'right';
            app.Label_11.FontSize = 14;
            app.Label_11.Position = [191 289 55 22];
            app.Label_11.Text = 'Επίθετο';

            % Create EntrySampleNameEditField
            app.EntrySampleNameEditField = uieditfield(app.RegisterSignalsTab, 'text');
            app.EntrySampleNameEditField.FontSize = 14;
            app.EntrySampleNameEditField.Position = [261 289 188 22];

            % Create RegisterNextButton
            app.RegisterNextButton = uibutton(app.RegisterSignalsTab, 'push');
            app.RegisterNextButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterNextButtonPushed, true);
            app.RegisterNextButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterNextButton.FontSize = 14;
            app.RegisterNextButton.Position = [349 191 100 24];
            app.RegisterNextButton.Text = 'Επόμενο';

            % Create WarnForExistingFolderLabel
            app.WarnForExistingFolderLabel = uilabel(app.RegisterSignalsTab);
            app.WarnForExistingFolderLabel.FontSize = 14;
            app.WarnForExistingFolderLabel.Visible = 'off';
            app.WarnForExistingFolderLabel.Position = [108 239 424 27];
            app.WarnForExistingFolderLabel.Text = 'Το όνομα αυτό υπάρχει στη βάση. Θέλετε να δώσετε νέα δείγματα;';

            % Create RegisterYesButton
            app.RegisterYesButton = uibutton(app.RegisterSignalsTab, 'push');
            app.RegisterYesButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterYesButtonPushed, true);
            app.RegisterYesButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterYesButton.FontSize = 14;
            app.RegisterYesButton.Visible = 'off';
            app.RegisterYesButton.Position = [211 131 59 27];
            app.RegisterYesButton.Text = 'Ναι';

            % Create RegisterNoButton
            app.RegisterNoButton = uibutton(app.RegisterSignalsTab, 'push');
            app.RegisterNoButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterNoButtonPushed, true);
            app.RegisterNoButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterNoButton.FontSize = 14;
            app.RegisterNoButton.Visible = 'off';
            app.RegisterNoButton.Position = [369 131 59 27];
            app.RegisterNoButton.Text = 'Όχι';

            % Create ExitToStartButton
            app.ExitToStartButton = uibutton(app.RegisterSignalsTab, 'push');
            app.ExitToStartButton.ButtonPushedFcn = createCallbackFcn(app, @ExitToStartButtonPushed, true);
            app.ExitToStartButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.ExitToStartButton.FontSize = 14;
            app.ExitToStartButton.Position = [191 191 100 24];
            app.ExitToStartButton.Text = 'Επιστροφή';

            % Create MassRecPreparationTab
            app.MassRecPreparationTab = uitab(app.TabGroup);
            app.MassRecPreparationTab.Title = 'Tab8';
            app.MassRecPreparationTab.BackgroundColor = [0.549 0.749 0.851];

            % Create RegisterRecLabel
            app.RegisterRecLabel = uilabel(app.MassRecPreparationTab);
            app.RegisterRecLabel.HorizontalAlignment = 'center';
            app.RegisterRecLabel.FontSize = 14;
            app.RegisterRecLabel.Position = [131 301 378 22];
            app.RegisterRecLabel.Text = 'Πατήστε το κουμπί για την έναρξης εγγραφής των σημάτων';

            % Create RegisterStartRecButton
            app.RegisterStartRecButton = uibutton(app.MassRecPreparationTab, 'push');
            app.RegisterStartRecButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterStartRecButtonPushed, true);
            app.RegisterStartRecButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterStartRecButton.FontSize = 14;
            app.RegisterStartRecButton.Position = [270 240 100 24];
            app.RegisterStartRecButton.Text = 'Εγγραφή';

            % Create Repeat20Label
            app.Repeat20Label = uilabel(app.MassRecPreparationTab);
            app.Repeat20Label.HorizontalAlignment = 'center';
            app.Repeat20Label.FontSize = 14;
            app.Repeat20Label.Position = [194 344 251 22];
            app.Repeat20Label.Text = 'Η διαδικασία θα επαναληφθεί 20 φορές';

            % Create SlowAndClearLabel
            app.SlowAndClearLabel = uilabel(app.MassRecPreparationTab);
            app.SlowAndClearLabel.HorizontalAlignment = 'center';
            app.SlowAndClearLabel.FontSize = 14;
            app.SlowAndClearLabel.Position = [171 391 298 22];
            app.SlowAndClearLabel.Text = 'Πείτε αργά και καθαρά το ονοματεπώνυμό σας';

            % Create StartRecordLabel
            app.StartRecordLabel = uilabel(app.MassRecPreparationTab);
            app.StartRecordLabel.FontName = 'Verdana';
            app.StartRecordLabel.FontWeight = 'bold';
            app.StartRecordLabel.FontColor = [1 0 0];
            app.StartRecordLabel.Visible = 'off';
            app.StartRecordLabel.Position = [293 200 64 22];
            app.StartRecordLabel.Text = 'Start rec';

            % Create EndRecordLabel
            app.EndRecordLabel = uilabel(app.MassRecPreparationTab);
            app.EndRecordLabel.FontName = 'Verdana';
            app.EndRecordLabel.FontWeight = 'bold';
            app.EndRecordLabel.FontColor = [1 0 0];
            app.EndRecordLabel.Visible = 'off';
            app.EndRecordLabel.Position = [293 164 59 22];
            app.EndRecordLabel.Text = 'End Rec';

            % Create IncRefFileNumberLabel
            app.IncRefFileNumberLabel = uilabel(app.MassRecPreparationTab);
            app.IncRefFileNumberLabel.HorizontalAlignment = 'center';
            app.IncRefFileNumberLabel.FontName = 'Tahoma';
            app.IncRefFileNumberLabel.FontSize = 14;
            app.IncRefFileNumberLabel.FontWeight = 'bold';
            app.IncRefFileNumberLabel.FontColor = [0 0.451 0.7412];
            app.IncRefFileNumberLabel.Visible = 'off';
            app.IncRefFileNumberLabel.Position = [406 200 136 22];

            % Create SelectVoiceFilesDB
            app.SelectVoiceFilesDB = uitab(app.TabGroup);
            app.SelectVoiceFilesDB.Title = 'Tab9';
            app.SelectVoiceFilesDB.BackgroundColor = [0.549 0.749 0.851];

            % Create SelectVoiceFilesLabel
            app.SelectVoiceFilesLabel = uilabel(app.SelectVoiceFilesDB);
            app.SelectVoiceFilesLabel.FontSize = 14;
            app.SelectVoiceFilesLabel.Position = [141 351 357 22];
            app.SelectVoiceFilesLabel.Text = 'Επιλέξτε τον φάκελο του προς ταυτοποίηση προσώπου ';

            % Create SelectVoiceFilesButton
            app.SelectVoiceFilesButton = uibutton(app.SelectVoiceFilesDB, 'state');
            app.SelectVoiceFilesButton.ValueChangedFcn = createCallbackFcn(app, @SelectVoiceFilesButtonValueChanged, true);
            app.SelectVoiceFilesButton.Text = 'Επιλέξτε αρχεία φωνής από τη βάση';
            app.SelectVoiceFilesButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SelectVoiceFilesButton.FontSize = 14;
            app.SelectVoiceFilesButton.Position = [199 240 244 24];
            app.SelectVoiceFilesButton.Value = true;

            % Create SelectVoiceFilesNextButton
            app.SelectVoiceFilesNextButton = uibutton(app.SelectVoiceFilesDB, 'state');
            app.SelectVoiceFilesNextButton.ValueChangedFcn = createCallbackFcn(app, @SelectVoiceFilesNextButtonValueChanged, true);
            app.SelectVoiceFilesNextButton.Visible = 'off';
            app.SelectVoiceFilesNextButton.Text = 'Επόμενο';
            app.SelectVoiceFilesNextButton.BackgroundColor = [0.8 0.8 0.8];
            app.SelectVoiceFilesNextButton.FontSize = 14;
            app.SelectVoiceFilesNextButton.Position = [270 185 100 24];
            app.SelectVoiceFilesNextButton.Value = true;

            % Create SelectVoiceDBFolderTab
            app.SelectVoiceDBFolderTab = uitab(app.TabGroup);
            app.SelectVoiceDBFolderTab.Title = 'Tab10';
            app.SelectVoiceDBFolderTab.BackgroundColor = [0.549 0.749 0.851];

            % Create SelectVoiceDBFolderLabel
            app.SelectVoiceDBFolderLabel = uilabel(app.SelectVoiceDBFolderTab);
            app.SelectVoiceDBFolderLabel.FontSize = 14;
            app.SelectVoiceDBFolderLabel.Position = [154 351 331 22];
            app.SelectVoiceDBFolderLabel.Text = 'Επιλέξτε τον φάκελο της βάσης φωνητικών αρχείων';

            % Create SelectVoiceDBFolderButton
            app.SelectVoiceDBFolderButton = uibutton(app.SelectVoiceDBFolderTab, 'state');
            app.SelectVoiceDBFolderButton.ValueChangedFcn = createCallbackFcn(app, @SelectVoiceDBFolderButtonValueChanged, true);
            app.SelectVoiceDBFolderButton.Text = 'Άνοιγμα...';
            app.SelectVoiceDBFolderButton.BackgroundColor = [0.902 0.902 0.902];
            app.SelectVoiceDBFolderButton.FontSize = 14;
            app.SelectVoiceDBFolderButton.Position = [270 240 100 24];
            app.SelectVoiceDBFolderButton.Value = true;

            % Create SelectVoiceDBNextButton
            app.SelectVoiceDBNextButton = uibutton(app.SelectVoiceDBFolderTab, 'state');
            app.SelectVoiceDBNextButton.ValueChangedFcn = createCallbackFcn(app, @SelectVoiceDBNextButtonValueChanged, true);
            app.SelectVoiceDBNextButton.Visible = 'off';
            app.SelectVoiceDBNextButton.Text = 'Επόμενο';
            app.SelectVoiceDBNextButton.BackgroundColor = [0.8 0.8 0.8];
            app.SelectVoiceDBNextButton.FontSize = 14;
            app.SelectVoiceDBNextButton.Position = [270 188 100 24];
            app.SelectVoiceDBNextButton.Value = true;

            % Create ChangeVoiceDBFolderButton
            app.ChangeVoiceDBFolderButton = uibutton(app.SelectVoiceDBFolderTab, 'state');
            app.ChangeVoiceDBFolderButton.ValueChangedFcn = createCallbackFcn(app, @ChangeVoiceDBFolderButtonValueChanged, true);
            app.ChangeVoiceDBFolderButton.Visible = 'off';
            app.ChangeVoiceDBFolderButton.Text = 'Αλλαγή Φακέλου...';
            app.ChangeVoiceDBFolderButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.ChangeVoiceDBFolderButton.FontSize = 14;
            app.ChangeVoiceDBFolderButton.Position = [254 240 132 24];
            app.ChangeVoiceDBFolderButton.Value = true;

            % Create CheckMassRecTab
            app.CheckMassRecTab = uitab(app.TabGroup);
            app.CheckMassRecTab.Title = 'Tab11';
            app.CheckMassRecTab.BackgroundColor = [0.549 0.749 0.851];

            % Create RegisterPlayRecButton
            app.RegisterPlayRecButton = uibutton(app.CheckMassRecTab, 'push');
            app.RegisterPlayRecButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterPlayRecButtonPushed, true);
            app.RegisterPlayRecButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterPlayRecButton.FontSize = 14;
            app.RegisterPlayRecButton.Position = [126 240 106 24];
            app.RegisterPlayRecButton.Text = 'Αναπαραγωγή';

            % Create RegisterRepeatRecButton
            app.RegisterRepeatRecButton = uibutton(app.CheckMassRecTab, 'push');
            app.RegisterRepeatRecButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterRepeatRecButtonPushed, true);
            app.RegisterRepeatRecButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterRepeatRecButton.FontSize = 14;
            app.RegisterRepeatRecButton.Position = [269 240 103 24];
            app.RegisterRepeatRecButton.Text = 'Επανεγγραφή';

            % Create RegisterAcceptRecButton
            app.RegisterAcceptRecButton = uibutton(app.CheckMassRecTab, 'push');
            app.RegisterAcceptRecButton.ButtonPushedFcn = createCallbackFcn(app, @RegisterAcceptRecButtonPushed, true);
            app.RegisterAcceptRecButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RegisterAcceptRecButton.FontSize = 14;
            app.RegisterAcceptRecButton.Position = [410 240 100 24];
            app.RegisterAcceptRecButton.Text = 'Αποδοχή';

            % Create CheckMassRecLabel
            app.CheckMassRecLabel = uilabel(app.CheckMassRecTab);
            app.CheckMassRecLabel.HorizontalAlignment = 'center';
            app.CheckMassRecLabel.FontSize = 14;
            app.CheckMassRecLabel.Position = [36 366 569 22];
            app.CheckMassRecLabel.Text = 'Έλεγχος για επανεγγραφή του δείγματος ή αποδοχή';
        end
    end

    methods (Access = public)

        % Construct app
        function app = AuthByVoice

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.AuthByVoiceUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.AuthByVoiceUIFigure)
        end
    end
end