% Rainfall Prediction GUI using LSTM
classdef RainfallPredictorAppLSTM < matlab.apps.AppBase

    % Properties
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        LoadDataButton      matlab.ui.control.Button
        PredictButton       matlab.ui.control.Button
        UITable             matlab.ui.control.Table
        UIAxes              matlab.ui.control.UIAxes
        ResultsTextArea     matlab.ui.control.TextArea
        TimeStepLabel       matlab.ui.control.Label
        TimeStepDropdown    matlab.ui.control.DropDown
        MoreInfoLabel       matlab.ui.control.Label
    end

    properties (Access = private)
        net  % LSTM Model
        X_min
        X_max
        timeStep = 7;
        rawData
    end

    % Startup function
    methods (Access = private)
        function startupFcn(app)
            if exist('modelGUILSTM.mat', 'file')
                s = load('modelGUILSTM.mat');
                app.net = s.net;
            else
                uialert(app.UIFigure, 'โมเดล modelGUILSTM.mat ไม่พบในโฟลเดอร์', 'ข้อผิดพลาด');
            end
        end
    end

    % Callbacks
    methods (Access = private)

        % Load Data Button pushed
        function LoadDataButtonPushed(app, event)
            [file, path] = uigetfile('*.xlsx');
            if isequal(file, 0)
                return;
            end
            data = readtable(fullfile(path, file));
            if ismember('Date', data.Properties.VariableNames)
                dateCol = data.Date;
                data.Date = [];
            else
                dateCol = NaT(height(data),1);
            end
            app.rawData = data;
            app.rawData.DateCol = dateCol;
            app.UITable.Data = data(1:min(10, height(data)), :);
        end

        % Predict Button pushed
        function PredictButtonPushed(app, event)
            if isempty(app.rawData)
                uialert(app.UIFigure, 'กรุณาโหลดข้อมูลก่อน', 'คำเตือน');
                return;
            end
            data = app.rawData;
            app.timeStep = str2double(app.TimeStepDropdown.Value);

            all_vars = data.Properties.VariableNames;
            all_vars = setdiff(all_vars, {'Rainfall', 'DateCol'});

            start_idx = 1; step = 1; stop_idx = numel(all_vars);
            selected_idx = start_idx:step:stop_idx;
            selected_idx = selected_idx(selected_idx <= numel(all_vars));
            selected_features = all_vars(selected_idx);

            X = data{:, selected_features};
            y = data.Rainfall;
            y_shifted = [y(2:end); NaN];
            dateCol = data.DateCol;
            date_shifted = [dateCol(2:end); NaT];

            valid_idx = ~isnan(y_shifted);
            X = X(valid_idx, :);
            y_shifted = y_shifted(valid_idx);
            date_shifted = date_shifted(valid_idx);

            X_seq = {};
            y_seq = [];
            date_seq = datetime.empty;
            for i = app.timeStep+1 : size(X,1)
                X_seq{end+1, 1} = X(i-app.timeStep:i-1, :)';
                y_seq(end+1, 1) = y_shifted(i);
                date_seq(end+1, 1) = date_shifted(i-1);
            end

            Xmat = cat(3, X_seq{:});
            app.X_min = min(Xmat, [], [2 3]);
            app.X_max = max(Xmat, [], [2 3]);

            for i = 1:length(X_seq)
                X_seq{i} = (X_seq{i} - app.X_min) ./ (app.X_max - app.X_min + eps);
            end

            y_pred = predict(app.net, X_seq);
            y_pred(y_pred < 0) = 0;
            y_true = y_seq;

            edges = [-inf, 0.1, 10, 35, 90, inf];
            labels = {'ฝนวัดไม่ได้ ⬛', 'ฝนตกน้อย 🟦', 'ฝนตกปานกลาง 🟩', 'ฝนตกหนัก 🟨', 'ฝนตกหนักมาก 🟥'};

            true_levels = discretize(y_true, edges, 'categorical', labels);
            predicted_levels = discretize(y_pred, edges, 'categorical', labels);

            n_show = min(length(y_pred));
            table_data = table(date_seq(1:n_show), y_true(1:n_show), y_pred(1:n_show), ...
                               true_levels(1:n_show), predicted_levels(1:n_show), ...
                               'VariableNames', {'วันที่', 'ค่าจริง (mm)', 'ค่าทำนาย (mm)', 'กลุ่มค่าจริง', 'กลุ่มค่าทำนาย'});
            app.UITable.Data = table_data;

            feature_list_str = strjoin(selected_features, ', ');
            resultText = sprintf('พยากรณ์เสร็จสิ้น ✅');
            app.ResultsTextArea.Value = resultText;
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = RainfallPredictorAppLSTM
            createComponents(app)
            runStartupFcn(app, @(app)startupFcn(app))
        end

        function delete(app)
            delete(app.UIFigure)
        end

    end

    % Component initialization
    methods (Access = private)
        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 700 500];
            app.UIFigure.Name = 'Rainfall Predictor - LSTM';
            app.UIFigure.WindowState = 'maximized';

            app.LoadDataButton = uibutton(app.UIFigure, 'push');
            app.LoadDataButton.Position = [20 370 100 30];
            app.LoadDataButton.Text = 'โหลดข้อมูล';
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.FontSize = 18;

            app.PredictButton = uibutton(app.UIFigure, 'push');
            app.PredictButton.Position = [140 370 100 30];
            app.PredictButton.Text = 'พยากรณ์';
            app.PredictButton.ButtonPushedFcn = createCallbackFcn(app, @PredictButtonPushed, true);
            app.PredictButton.FontSize = 18;

            app.UITable = uitable(app.UIFigure);
            app.UITable.Position = [20 150 660 200];
            app.UITable.FontSize = 18;

            app.ResultsTextArea = uitextarea(app.UIFigure);
            app.ResultsTextArea.Position = [20 100 660 25];
            app.ResultsTextArea.Editable = false;
            app.ResultsTextArea.Value = {'รอผลลัพธ์พยากรณ์...'};
            app.ResultsTextArea.FontSize = 40;
            app.ResultsTextArea.HorizontalAlignment = 'center';

            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [340 50 340 130];
            title(app.UIAxes, 'Actual vs Predicted');
            app.UIAxes.Visible = 'off';

            app.TimeStepLabel = uilabel(app.UIFigure);
            app.TimeStepLabel.Position = [260 370 200 30];
            app.TimeStepLabel.Text = 'พยากรณ์ล่วงหน้า (วัน):';
            app.TimeStepLabel.FontSize = 18;

            app.TimeStepDropdown = uidropdown(app.UIFigure);
            app.TimeStepDropdown.Position = [450 370 30 30];
            app.TimeStepDropdown.Items = {'1','3','5','7','14','30'};
            app.TimeStepDropdown.Value = '7';
            app.TimeStepDropdown.FontSize = 18;

            app.MoreInfoLabel = uilabel(app.UIFigure);
            app.MoreInfoLabel.Position = [60 430 450 50]; % ปรับตามต้องการ
            app.MoreInfoLabel.Text = 'LSTM Model Prediction Rainfall';
            app.MoreInfoLabel.FontSize = 30;


            app.MoreInfoLabel = uilabel(app.UIFigure);
            app.MoreInfoLabel.Position = [20 35 660 30];
            app.MoreInfoLabel.Text = 'กลุ่มฝน: ⬛ ฝนวัดไม่ได้ (<0.1 mm) 🟦 ฝนตกน้อย (0.1-10 mm) 🟩 ฝนตกปานกลาง (10.1-35 mm) 🟨 ฝนตกหนัก (35.1-90 mm) 🟥 ฝนตกหนักมาก (>90 mm)';
            app.MoreInfoLabel.FontSize = 18;
            app.MoreInfoLabel.HorizontalAlignment = 'center';

            app.UIFigure.Visible = 'on';
        end
    end
end










