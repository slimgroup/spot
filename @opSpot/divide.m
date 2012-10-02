function x = divide(op,b,mode)
%\  Backslash or left matrix divide.
%
%   X = A\B is similar to Matlab's backslash operator, except that A
%   is always a Spot operator, and b is always a numeric column
%   vector. X is computed as the solution to the least-squares problem
%
%   (*)  minimize  ||Ax - b||_2.
%
%   The least-squares problem (*) is solved using LSQR with default
%   parameters specified by spotparams.
%
%   See also mldivide, opSpot.mrdivide, opFoG, opInverse, opPInverse, spotparams.

%   Copyright 2009, Ewout van den Berg and Michael P. Friedlander
%   See the file COPYING.txt for full copyright information.
%   Use the command 'spot.gpl' to locate this file.

%   http://www.cs.ubc.ca/labs/scl/spot

if op.sweepflag
    if mode == 1
        x = matldivide(op,b);
    else
        x = matldivide(op',b);
    end
else
    if mode == 1
        x = lsqrdivide(op,b);
    else
        x = lsqrdivide(op',b);
    end
end