function [inStartA, inEndA, inStartB, inEndB] = initialize(dataA, dataB, cat)
inStartA = dataA(cat, 2);
inEndA = dataA(cat,3);
inStartB = dataB(cat,2);
inEndB = dataB(cat,3);
end

