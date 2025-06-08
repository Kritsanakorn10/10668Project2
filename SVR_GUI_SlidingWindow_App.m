classdef SVR_GUI_SlidingWindow_App < matlab.apps.AppBase
    % Properties (UI Components)
    properties (Access = public)
        MoreInfoLabel      matlab.ui.control.Label 
        UIFigure           matlab.ui.Figure
        LoadDataButton     matlab.ui.control.Button
        PredictButton      matlab.ui.control.Button
        UITable            matlab.ui.control.Table
        LookbackDropDown   matlab.ui.control.DropDown
        LookbackLabel      matlab.ui.control.Label
        StatusLabel        matlab.ui.control.Label
    end
    
    % Properties (Data & Model)
    properties (Access = private)
        mdl_svr
        ps
        feature_cols
        data
        lookback
    end
    
    methods (Access = private)
        
        function loadModel(app)
            % โหลดโมเดลตาม sliding window ที่เลือก
            lookback_selected = str2double(app.LookbackDropDown.Value);
            modelFile = sprintf('modelGUISVR_Lookback%d.mat', lookback_selected);
            if isfile(modelFile)
                S = load(modelFile, 'mdl_svr', 'ps', 'feature_cols');
                app.mdl_svr = S.mdl_svr;
                app.ps = S.ps;
                app.feature_cols = S.feature_cols;
                app.lookback = lookback_selected;
                app.StatusLabel.Text = sprintf('โหลดโมเดล Lookback %d วัน เรียบร้อย', lookback_selected);
            else
                app.StatusLabel.Text = sprintf('ไม่พบไฟล์โมเดล: %s', modelFile);
                app.mdl_svr = [];
                app.ps = [];
                app.feature_cols = [];
                app.lookback = [];
            end
        end
        
        function loadData(app)
            if isempty(app.mdl_svr)
                app.StatusLabel.Text = 'กรุณาโหลดโมเดลก่อน';
                return;
            end
            
            [file, path] = uigetfile('*.xlsx', 'เลือกไฟล์ข้อมูล');
            if isequal(file, 0)
                return;
            end
            
            T = readtable(fullfile(path, file));
            if ismember('Date', T.Properties.VariableNames)
                dates = T.Date;
                T.Date = [];
            else
                dates = (1:height(T))';
            end
            
            T = rmmissing(T);
            
            if ~all(ismember(app.feature_cols, T.Properties.VariableNames))
                app.StatusLabel.Text = 'ฟีเจอร์ในไฟล์ไม่ตรงกับโมเดล';
                return;
            end
            
            X_raw = T{:, app.feature_cols};
            y_raw = T.Rainfall;
            num_samples = size(X_raw, 1) - app.lookback;
            if num_samples <= 0
                app.StatusLabel.Text = 'ข้อมูลไม่เพียงพอตาม sliding window ที่เลือก';
                return;
            end
            
            X = zeros(num_samples, app.lookback * size(X_raw,2));
            y = zeros(num_samples, 1);
            sample_dates = strings(num_samples, 1);
            
            for i = 1:num_samples
                window = X_raw(i:i+app.lookback-1, :);
                X(i,:) = reshape(window', 1, []);
                y(i) = y_raw(i+app.lookback);
                if isdatetime(dates)
                    sample_dates(i) = datestr(dates(i + app.lookback));
                else
                    sample_dates(i) = string(dates(i + app.lookback));
                end
            end
            
            app.data.X = X;
            app.data.y = y;
            app.data.dates = sample_dates;
            
            app.StatusLabel.Text = 'โหลดข้อมูลเรียบร้อย';
        end
        
        function predict(app)
            if isempty(app.data) || ~isfield(app.data, 'X')
                app.StatusLabel.Text = 'กรุณาโหลดข้อมูลก่อน';
                return;
            end
            
            try
                X_scaled = mapminmax('apply', app.data.X', app.ps)';
            catch ME
                app.StatusLabel.Text = ['Error ในการ scale ข้อมูล: ' ME.message];
                return;
            end
            
            y_pred = predict(app.mdl_svr, X_scaled);
            y_pred(y_pred < 0) = 0;
            
            categorize = @(x) (x < 0.1)*1 + (x >= 0.1 & x <=10)*2 + ...
                              (x > 10 & x <=35)*3 + (x > 35 & x <=90)*4 + (x > 90)*5;
            
            labels = {
                'ฝนวัดไม่ได้ ⬛'
                'ฝนตกน้อย 🟦'
                'ฝนตกปานกลาง 🟩'
                'ฝนตกหนัก 🟨'
                'ฝนตกหนักมาก 🟥'
            };
            
            actual_grp_idx = arrayfun(categorize, app.data.y);
            pred_grp_idx = arrayfun(categorize, y_pred);
            
            actual_grp_str = labels(actual_grp_idx);
            pred_grp_str = labels(pred_grp_idx);
            
            tbl_data = table(app.data.dates, app.data.y, y_pred, ...
                             actual_grp_str, pred_grp_str, ...
                             'VariableNames', {'วันที่', 'ค่าจริง_มม', 'ค่าทำนาย_มม', 'กลุ่มค่าจริง', 'กลุ่มค่าทำนาย'});
            
            app.UITable.Data = tbl_data;
            app.StatusLabel.Text = 'ทำนายเรียบร้อย';
        end
    end
    
    methods (Access = private)
        % Callback: เลือก sliding window เปลี่ยนโมเดล
        function LookbackDropDownValueChanged(app, event)
            app.loadModel();
            app.UITable.Data = []; % เคลียร์ตารางเก่า
            app.data = [];
        end
        
        % Callback: ปุ่มโหลดข้อมูล
        function LoadDataButtonPushed(app, event)
            app.loadData();
        end
        
        % Callback: ปุ่มทำนาย
        function PredictButtonPushed(app, event)
            app.predict();
        end
    end
    
    methods (Access = public)
        
        % Constructor
        function app = SVR_GUI_SlidingWindow_App
            
            app.UIFigure = uifigure('Name', 'พยากรณ์ฝนด้วย SVR (Sliding Window)', ...
                                   'Position', [100 100 660 450]);
            
            app.UIFigure.WindowState = 'maximized';

            % Label สำหรับ dropdown
            app.LookbackLabel = uilabel(app.UIFigure, ...
                'Position', [380 450 250 26], ...
                'Text', 'เลือก Sliding Window :', ...
                'FontSize', 18);
            
            % Dropdown เลือก sliding window
            app.LookbackDropDown = uidropdown(app.UIFigure, ...
                'Items', {'7', '14', '30'}, ...
                'Position', [600 450 1 26], ...
                'Value', '7', ...
                'FontSize', 18, ...
                'ValueChangedFcn', @(dd,event) app.LookbackDropDownValueChanged(event));
            
            % ปุ่มโหลดข้อมูล
            app.LoadDataButton = uibutton(app.UIFigure, ...
                'Position', [30 440 150 40], ...
                'Text', 'โหลดข้อมูล Excel', ...
                'FontSize', 18, ...
                'ButtonPushedFcn', @(btn,event) app.LoadDataButtonPushed(event));
            
            % ปุ่มทำนาย
            app.PredictButton = uibutton(app.UIFigure, ...
                'Position', [200 440 150 40], ...
                'Text', 'ทำนาย', ...
                'FontSize', 18, ...
                'ButtonPushedFcn', @(btn,event) app.PredictButtonPushed(event));
            
            % ตารางแสดงผล
            app.UITable = uitable(app.UIFigure, ...
                'Position', [20 230 600 200], ...
                'FontSize', 18);
            
            % Label แสดงสถานะ
            app.StatusLabel = uilabel(app.UIFigure, ...
                'Position', [20 30 600 30], ...
                'Text', '', ...
                'FontColor', [0 0 1], ...
                'FontSize', 20, ...
                'HorizontalAlignment', 'center');
            
% เพิ่ม Label แสดงข้อมูลกลุ่มฝน
            app.MoreInfoLabel = uilabel(app.UIFigure);
            app.MoreInfoLabel.Position = [20 80 600 30]; % ปรับขนาดกว้างให้เต็มที่กับตาราง
            app.MoreInfoLabel.Text = ['กลุ่มฝน: ⬛ ฝนวัดไม่ได้ (<0.1 mm)  ' ...
                         '🟦 ฝนตกน้อย (0.1-10 mm) ' ...
                         '🟩 ฝนตกปานกลาง (10.1-35 mm) ' ...
                         '🟨 ฝนตกหนัก (35.1-90 mm) ' ...
                         '🟥 ฝนตกหนักมาก (>90 mm)'];
            app.MoreInfoLabel.FontSize = 18;
            app.MoreInfoLabel.HorizontalAlignment = 'center';

            app.MoreInfoLabel = uilabel(app.UIFigure);
            app.MoreInfoLabel.Position = [20 150 600 40]; % ปรับขนาดกว้างให้เต็มที่กับตาราง
            app.MoreInfoLabel.Text = 'SVR Pred Rainfall Sliding Window';
            app.MoreInfoLabel.FontSize = 30;
            app.MoreInfoLabel.HorizontalAlignment = 'center';



            % โหลดโมเดลเริ่มต้น (lookback=7)
            app.loadModel();
        end
        
        function delete(app)
            delete(app.UIFigure);
        end
    end
end
