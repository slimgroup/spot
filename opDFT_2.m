classdef opDFT_2 < opOrthogonal_2
%opDFT_2  Fast Fourier transform (DFT).
%
%   opDFT_2(M) create a unitary one-dimensional discrete Fourier
%   transform (DFT) for vectors of length M.
%
%   opDFT_2(M,CENTERED), with the CENTERED flag set to true, creates a
%   unitary DFT that shifts the zero-frequency component to the center
%   of the spectrum.
%
%   opDFT_2({C,dim1}) create an unitary one-dimensional discrete Fourier
%   transform (DFT) for vectors of length size(C).
%
%   opDFT_2({C,dim1},CENTERED), with the CENTERED flag set to true, creates a
%   unitary DFT that shifts the zero-frequency component to the center
%   of the spectrum.


%   Copyright 2009, Ewout van den Berg and Michael P. Friedlander
%   See the file COPYING.txt for full copyright information.
%   Use the command 'spot.gpl' to locate this file.

%   http://www.cs.ubc.ca/labs/scl/spot

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Properties
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    properties ( Access = private )
        funHandle % Multiplication function
    end % private properties

    properties ( SetAccess = private, GetAccess = public )
        centered
    end % set-private get-public properties

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods - public
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Constructor
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function op = opDFT_2(varargin)
            
            if nargin > 0
                m = varargin{1};
            else
                m = nan;
            end
            activated = (nargin > 0) && isnumeric(m);
            
            if activated
                if iscell(m)
                    refDim = m;
                    refDim(1) = []; % remove the dataContainer
                    refDim = spot.utils.uncell(refDim);
                    
                    if ~isempty(refDim) % make sure there are dimensions selected
                        if ~all(refDim <= length(size(m{1}))) % incase over-selecting
                            error('invalid dimension selected for data container')
                        end
                        theNs = size(m{1},refDim);
                    else
                        error('invalid dataContainer refrerncing dimension info'); % please make sure at least 1 dimension of C is selected
                    end
                    varargin(1) = [];
                else %numeric
                    varargin(1) = [];
                end
            else
                m = nan;
            end
            
            % check centered arguement
            centred = false; % set centred to false by default
            if length(varargin) == 1 % if centered arguement is specified (remember varargin(1) is removed earlier)
                arg2 = varargin{1};
                if ~(islogical(arg2) || arg2 == 1 || arg2 == 0) % make sure the 2nd (centred) arguement makes sense. True or False or 1 or 0.
                    error(strcat('Invalid centered arguement of type "',class(arg2),'"'))
                end
                centred = true == arg2;
                
            elseif length(varargin) > 2
                error('opDFT_2 should not have more than 2 input arguments')
            end
            
            % create the operator
            op = op@opOrthogonal_2('DFT_2',m,m);
            op.centered  = centred;
            op.cflag     = true;
            op.sweepflag = true;
            % Create function handle
            if centred
                op.funHandle = @opDFT_2_centered_intrnl;
            else
                op.funHandle = @opDFT_2_intrnl;
            end
        end % constructor
        
        function op = activateOp(op,header,~)
            % activate the operator right before it operates on container
            % header : the header of the data container
            m = header.size;
            if any(strcmp('exsize',fieldnames(header)))
                m = prod(m(header.exsize(1,1):header.exsize(2,1)));
            else
                warning('exsize field not exist in header')
                m = prod(m); % assume container is vectorized
            end
            
            % from opSpot's constructor.
            % make up what the operator missed during it was initialized.
            m = max(0,m);
            if round(m) ~= m
                warning('SPOT:ambiguousParams',...
                    'Size parameters are not integer.');
                m = floor(m);
            end
            op.m    = m;
            op.n    = m;
            op.ms   = {m};
            op.ns   = {m};
            
            op.activated = true; % activation complete
        end
        function dim = takesDim(~,~)
            % returns the number of dimension the operator operates on the
            % dataContainer.
            dim = 1;
        end
        
    end % methods - public

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods - protected
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Access = protected )
        % Multiplication
        function y = multiply(op,x,mode)
            y = op.funHandle(op,x,mode);
        end % Multiply

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Divide
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function x = divide(op,b,mode)
            % Sweepable
            x = matldivide(op,b,mode);
        end % divide
    end % protected methods

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods - private
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Access = private )
        function y = opDFT_2_intrnl(op,x,mode)
            % One-dimensional DFT
            n = op.n;
            if mode == 1
                % Analysis
                y = fft(full(x));
                y = y / sqrt(n);
            else
                % Synthesis
                y = ifft(full(x));
                y = y * sqrt(n);
            end
        end % opDFT_2_intrnl
        function y = opDFT_2_centered_intrnl(op,x,mode)
            % One-dimensional DFT - Centered
            n = op.n;
            if mode == 1
                y = fftshift(fft(full(x)));
                y = y / sqrt(n);
            else
                y = ifft(ifftshift(full(x)));
                y = y * sqrt(n);
            end
        end % opDFT_2_centered_intrnl
    end % private methods
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods - Static
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods( Static )
        function fh = default_full_handler()
            fh = @(header,op,mode)default_full_handler_helper(header,op,mode);
            
            function h = default_full_handler_helper(header,op,mode)
                exsize = header.exsize;
                
                if mode == 1
                    h = header; % Copy header
                    % Replace old first (collapsed) dimensional sizes with operator sizes.
                    h.size(exsize(1,1):exsize(2,1)) = [];
                    h.size = [op.ms{:} h.size];
                else
                    h = header;
                    h.size(exsize(1,1):exsize(2,1)) = [];
                    h.size = [op.ns{:} h.size];
                end
                
                exsize_out = 1:length(h.size);
                exsize_out = [exsize_out;exsize_out];
                h.exsize   = exsize_out;
                
                % modify unit, origin, offset, varName, varUnit, etc
%                 h = SDCpckg.utils.modifyAdditionalMetadata(op,header,mode);
                
                % modification based on history
                if ~isempty(h.IDHistory) % if the operation history is not empty
                    prevHis = peek(h.IDHistory);
                    
                    prevHisID = prevHis.ID;
                    
                    if ~strcmp(prevHisID,op.ID) %if IDs are different
                        h.IDHistory = push(h.IDHistory,{...
                            {'ID',op.ID},...
                            {'ClassName',class(op)},...
                            {'mode',mode},...
                            {'opM',op.m},...
                            {'opN',op.n},...
                            {'origin',header.origin},...
                            {'children',2}});
                    else % if IDs are the same
                        prevHisMode = prevHis.mode;
                        
                        if strcmp(prevHisMode,mode) % if modes are the same
                            h.IDHistory = push(h.IDHistory,{...
                                {'ID',op.ID},...
                                {'ClassName',class(op)},...
                                {'mode',mode},...
                                {'origin',header.origin}
                                {'opM',op.m},...
                                {'opN',op.n},...
                                {'children',{}}});
                        else % if modes are opposite
                            h.IDHistory = remove(h.IDHistory,1); % cancel out
                            prevHisOrigin = prevHis.origin;
                            h.origin = prevHisOrigin;
                        end
                    end
                else % if it is empty ...
                    h.IDHistory = push(h.IDHistory,{...
                        {'ID',op.ID},...
                        {'ClassName',class(op)},...
                        {'mode',mode},...
                        {'origin',header.origin},...
                        {'opM',op.m},...
                        {'opN',op.n},...
                        {'children',{}}});
                end
            end
        end
        
        function fh = default_unit_handler()
            fh = @(header,op,mode)default_unit_handler_helper(header,op,mode);
            
            function newUnit = default_unit_handler_helper(header,~,~)
                unit = header.unit;
                currentUnit = unit{1};
                newUnit = unit;
                
                if isa(currentUnit,'sUnit')
                    newUnit{1} = 1/currentUnit;
                else % if is char unit
                    if sLength.existsUnit(currentUnit) || sTime.existsUnit(currentUnit)
                        currentUnit = strcat('1/',currentUnit);
                        newUnit{1} = currentUnit;
                    else
                        warning('could not detect the unit. Unit set to (aUnit)')
                        newUnit{1} = 'aUnit';
                    end
                end
            end
        end
        function fh = default_delta_handler()
            fh = @(header,op,mode)default_delta_handler_helper(header,op,mode);
            
            function deltaOut = default_delta_handler_helper(header,~,~)
                deltaIn = header.delta;
                
                dataSize = header.size;
                
                deltaOut = deltaIn;
                deltaOut(1) = 1/((dataSize(1) - 1) * deltaIn(1));
            end
        end
        function fh = default_size_handler()
            fh = @(header,op,mode)default_size_handler_helper(header,op,mode);
            
            function sizeOut = default_size_handler_helper(header,op,mode)
                exsize = header.exsize;
                
                sizeOut = header.size;
                if mode == 1
                    sizeOut(exsize(1,1):exsize(2,1)) = [];
                    sizeOut = [op.ms{:} sizeOut];
                else
                    sizeOut(exsize(1,1):exsize(2,1)) = [];
                    sizeOut = [op.ns{:} sizeOut];
                end
            end
        end
    end
end % opDFT_2




