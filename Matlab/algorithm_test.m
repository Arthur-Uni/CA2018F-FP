%% clean up
clear;
clc;

%% load stuff
load('data.mat');

%% set up all parameters from the data similar to intervalJoin.h in a matrix
number_of_categories = metaA(1,1);

length_A = metaA(2,2);
length_B = metaB(2,2);

indices = zeros(number_of_categories, 3);

for j=1:length_B
    [inStartB, inEndB] = getBoundsB(dataB, j);
    start_index = 0;
    end_index = 0;
    for i=1:length_A
        [inStartA, inEndA] = getBoundsA(dataA,i);
        if( start_index == 0 && ((inStartA>=inStartB && inStartA<=inEndB) || ... %case 1
            (inEndA>=inStartB && inEndA<=inEndB) || ... %case 2
            (inStartA>=inStartB && inEndA<=inEndB) || ... %case 3
            (inStartA<=inStartB && inEndA>=inEndB)) )  %case 4
                % start index is the first time the if condition is true
                start_index = i;
                % end index necessarily starts from here too
                end_index = i;
        elseif ( ((inStartA>=inStartB && inStartA<=inEndB) || ... %case 1
            (inEndA>=inStartB && inEndA<=inEndB) || ... %case 2
            (inStartA>=inStartB && inEndA<=inEndB) || ... %case 3
            (inStartA<=inStartB && inEndA>=inEndB)) ) %case 4
                % increment end index as long as the condition is true
                end_index = end_index + 1;
        end
    end
    indices(j,1:3) = [1 start_index end_index];
end