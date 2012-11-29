classdef opDictionary < opSpot
%OPDICTIONARY   Dictionary of concatenated operators.
%
%   D = opDictionary(WEIGHTS,OP1,OP2,...OPn) creates a dictionary
%   operator consisting of the concatenation of all operators, i.e.,
%   
%       D = [ WEIGHT1*OP1, WEIGHT2*OP2, ..., WEIGHTn*OPn ].
%
%   In general, it's best to use Matlab's horizonal concatenation
%   operations instead of calling opDictionary. (The two are equivalent.)
%
%   See also opFoG, opStack, opSum, @opSpot/horzcat.

%   Copyright 2008-2009, Ewout van den Berg and Michael P. Friedlander
%   See the file COPYING.txt for full copyright information.
%   Use the command 'spot.gpl' to locate this file.

%   http://www.cs.ubc.ca/labs/scl/spot
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods

       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % Constructor
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       function op = opDictionary(varargin)
          
          % Checks weights parameter
          if ~isnumeric(varargin{1})
             weights = ones(nargin,1);
             opList  = varargin;
          else
             weights = varargin{1};
             if isempty(weights), weights = 1; end;
             [m,n]   = size(weights);
             if (((m == 1) && (n == nargin-1)) || ...
                 ((n == 1) && (m == nargin-1)) || ...
                 ((m == 1) && (n == 1)))
               weights = ones(nargin-1,1).*weights(:); 
               opList  = varargin(2:end);
             else
               weights = ones(nargin,1);
               opList  = varargin;
             end
          end
          
          % Check number of operators
          if isempty(opList)
             error('At least one operator must be specified.');
          end

          % Convert all arguments to operators
          for i=1:length(opList)
             if ~isa(opList{i},'opSpot')
                opList{i} = opMatrix(opList{i});
             end
          end

          % Check operator consistency and complexity
          opA    = opList{1};
          [m,n]  = size(opA);
          cflag  = ~isreal(opA);
          linear = opA.linear;
          for i=2:length(opList)
             opA    = opList{i};
             cflag  = cflag  | ~isreal(opA); % Update complexity information
             linear = linear & opA.linear;
   
             % Generate error if operator sizes are incompatible
             if (size(opA,1) ~= m) && ~isempty(opA)
               error('Operator %d is not consistent with the previous operators.',i);
             end

             n = n + size(opA,2); % Total number of columns
          end

          % Filter out all empty operators
          opListNew = {};
          for i=1:length(opList)
            if ~isempty(opList{i})
              opListNew{end+1} = opList{i};
            end
          end
          
          % Construct operator
          op = op@opSpot('Dictionary', m, n);
          op.cflag      = cflag;
          op.linear     = linear;
          op.children   = opListNew;
          op.precedence = 1;
          op.weights    = weights;
       end
      
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % Display
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       function str = char(op)
          % Initialize
          str = '[';
       
          for i=1:length(op.children)
             strOp = char(op.children{i});
             if i~=1
                str = [str, ', ', strOp];
             else
                str = [str, strOp];
             end             
          end
          
          str = [str, ']'];
       end % Display
       
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % Double
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       function A = double(op)
          A = zeros(size(op));
          k = 0;
          for i=1:length(op.children)
             child = op.children{i};
             n = size(child,2);
             A(:,k+1:k+n) = double(child);
             k = k + n;
          end
       end % double

    end % Methods
       
 
    methods ( Access = protected )
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % Multiply
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       function y = multiply(op,x,mode)
           x_n = size(x,2);
          if mode == 1
              if isscalar(op)
                  % special case: allocate result size of x
                  y = zeros(size(x),class(x));
              else
                  y = zeros(op.m,x_n, class(x));
              end
             
             for u = 1:x_n
                k = 0;
                 x_tmp = x(:,u);
                 for i=1:length(op.children)
                    child = op.children{i};
                    s = size(child,2);
                    y(:,u) = y(:,u) + op.weights(i) * multiply(child, x_tmp(k+1:k+s), 1);
                    k = k + s;
                 end
             end
          else
             if isscalar(op)
                 % special case: allocate result size of x
                 y = zeros(size(x),class(x));
             else
                 y = zeros(op.n,x_n, class(x));
             end
             for u = 1:x_n
                k = 0;
                 y_tmp = y(:,u);
                 for i=1:length(op.children)
                    child = op.children{i};
                    s          = size(child,2);
                    y_tmp(k+1:k+s) = conj(op.weights(i)) * multiply(child, x(:,u), 2);
                    k          = k + s;
                 end
                 y(:,u) = y_tmp;
             end
          end
       end % Multiply
       
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % Divide
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       function x = divide(op,b,mode)
           % Non-sweepable
           x = lsqrdivide(op,b,mode);
       end % divide

    end % Methods
   
end % Classdef
