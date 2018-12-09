function [dataSet] = getDataSet(data, dataLength, dataCategory)

A = data(:,1) == dataCategory;
temp = A.*data;
temp(temp==0) = [];
dataSet = reshape(temp, dataLength, 3);

end

