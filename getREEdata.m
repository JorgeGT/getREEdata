function [tsDem,demand,tsPrev,prevision,tsPric,priceGen,priceNoc,priceVhc] = getREEData(day)
% The MIT License (MIT)

% Copyright (c) 2015 Jorge Garcia

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

% - Input day in 'yyyy-mm-dd' format
% - See each section below for structure field descriptions
% - All output temporal vectors ts* in standard MATLAB format

%% Generation structure
%  Fields: https://demanda.ree.es/movil/peninsula/demanda/tablas/2
try
    demand = urlread(['https://demanda.ree.es/WSvisionaMovilesPeninsulaRest/resources/demandaGeneracionPeninsula?callback=angular.callbacks._2&curva=DEMANDA&fecha=' day]);
    demand = demand(22:end-2);
    demand = fromjson(demand);
    demand = demand.valoresHorariosGeneracion;
    demand = cell2mat(demand);
    tsDem   = datenum(reshape([demand.ts],16,length(demand))');
catch
    disp('Error: generation')
    demand = 0;
    tsDem  = 0;
end

%% Total demand and prevision
%  Fields: https://demanda.ree.es/movil/peninsula/demanda/tablas/1
try
    prevision = urlread(['https://demanda.ree.es/WSvisionaMovilesPeninsulaRest/resources/prevProgPeninsula?callback=angular.callbacks._1&curva=DEMANDA&fecha=' day]);
    prevision = prevision(22:end-2);
    prevision = fromjson(prevision);
    prevision = prevision.valoresPrevistaProgramada;
    prevision = cell2mat(prevision);
    tsPrev    = datenum(reshape([prevision.ts],16,length(prevision))');
catch
    disp('Error: totals')
    prevision = 0;
    tsPrev    = 0;
end

%% Price for small consumers
%  Gen: default 2.0 A
%  Noc: efficiency 2 periods 2.0 DHA
%  Vhc: electric vehicle 2.0 DHS
try
    price = urlread(['http://www.esios.ree.es/Solicitar?fileName=PVPC_CURV_DD_' datestr(datenum(day),'YYYYmmDD') '&fileType=txt&idioma=es']);
    price(regexpi(price,'\d,\d')+1) = '.';
    price = fromjson(price);
    price = price.PVPC;
    price = cell2mat(price);
    priceGen = str2num(char(price.GEN));  %#ok<*ST2NM>
    priceNoc = str2num(char(price.NOC)); 
    priceVhc = str2num(char(price.VHC)); 
    tsPric   = datenum(datestr(datenum(day)+(0.5:23.5)/24));
catch
    disp('Error: price')
    priceGen = 0;
    priceNoc = 0;
    priceVhc = 0;
    tsPric   = 0;
end
