function X = preprocessInput(dataTable)
data = readtable('data_rainfall.xlsx');
X = preprocessInput(data);

    % ฟีเจอร์ที่ใช้
    feature_cols = {'MaxAirPressure','MinAirPressure','AvgAirPressure8Time',...
                    'MaxTemp','MinTemp','AvgTemp','Evaporation',...
                    'MaxHumidity','MinHumidity','AvgHumidity'};

    % 1. ดึงข้อมูลเฉพาะฟีเจอร์
    Xraw = dataTable{:, feature_cols};

    % 2. ลบแถวที่มี missing
    Xraw = Xraw(~any(isnan(Xraw),2), :);

    % 3. สร้าง sliding window (ย้อนหลัง 7 วัน)
    timeStep = 7;
    X = {};
    for i = timeStep+1 : size(Xraw,1)
        seq = Xraw(i-timeStep:i-1, :)';

        % 4. Normalize แบบ Min-Max (ใช้ค่าคงที่จาก training set)
        % ต้องแนบ min/max ตอน train ลงไปในฟังก์ชันหรือเป็นไฟล์เสริม
        % *** ปรับค่าต่อไปนี้ให้ตรงกับที่คุณใช้จริงตอน train ***
        X_min = [992.8; 985.2; 988.6; 22.0; 20.1; 21.1; 0; 50.0; 48.0; 49.0];
        X_max = [1012.5; 1005.2; 1008.6; 35.0; 30.1; 32.1; 8; 98.0; 96.0; 97.0];
        seq = (seq - X_min) ./ (X_max - X_min + eps);

        % 5. บันทึกเป็น sequence
        X{end+1,1} = seq;
    end
end
