# Accediendo a datos de la Red Eléctrica de España a través de MATLAB

*La red eléctrica es uno de los más activos más importantes y complejos de cualquier país. En esta entrada se muestra como usar una sencilla función de MATLAB para acceder a datos históricos y en tiempo real de Red Eléctrica de España y algunos ejemplos de sus posibles aplicaciones.*

La energía que inviertes en encender una bombilla empieza su camino de muchas formas: brilla el Sol en una de las centrales termosolares de Almería, se levanta una brisa en un parque eólico en Castilla, acelera una turbina hidroeléctrica en Galicia, se quema carbón de Asturias, se fisiona un átomo en Valencia...

Mantener el balance de un sistema con cientos de estaciones de generación y millones de puntos de suministro es un un gigantesco rompecabezas del que se ocupa [REE](http://www.ree.es/es/). A pesar de que recientemente han actualizado su [web de datos](https://www.esios.ree.es/es) con magnífico resultado, sigue faltando una API pública que permita consultar automáticamente los datos del sistema. Mientras llega, esta sencilla [función de MATLAB](https://gist.github.com/JorgeGT/90600572df235b896611) nos permite obtener algunos interesantes resultados, que se muestran a continuación.

## 1. Datos del día
Tal y como están estructuradas las fuentes de datos que usa la función, se obtienen los datos del día presente en tiempo real o bien los de cualquier día anterior que se encuentre en el archivo. A continuación se demuestra el acceso a cada una de las tres fuentes de datos para un día determinado, que debe ser introducido en el formato `yyyy-mm-dd`, como por ejemplo `day = 2015-08-06`.

### 1.1. Demanda total

En primer lugar, podemos observar cuál es la demanda actual de todo el sistema eléctrico, así como la demanda estimada por el modelo de comportamiento que tiene REE y la programación de la energía que en base a ese modelo deberá estar disponible a cada hora del día:

```matlab
%% Total demand and prevision
try
    prevision = urlread(['https://demanda.ree.es/WSvisionaMovilesPeninsula
        Rest/resources/prevProgPeninsula?callback=angular.callbacks._1
        &curva=DEMANDA
        &fecha=' day]);
    prevision = prevision(22:end-2); % Cut extra text
    prevision = fromjson(prevision); % External function
    prevision = prevision.valoresPrevistaProgramada;
    prevision = cell2mat(prevision);
    tsPrev    = datenum(reshape([prevision.ts],16,length(prevision))');
catch
    disp('Error: totals')
    prevision = 0;
    tsPrev    = 0;
end
```

El código devuelve una estructura llamada `prevision` con los datos. Para graficarla convertimos el dato de tiempo `prevision.ts` a un vector de tiempos de MATLAB `tsPrev`. El resultado es el siguiente: 

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g12015-08-01.png" alt=""></figure>

Se aprecia lo preciso del modelo! Luego volveremos a hablar sobre esta precisión, pero decididamente en REE tienen bastante bien modelado cómo nos comportamos un día cualquiera. Respecto a la curva en sí, se observa lo tarde que cenamos los españoles viendo el pico de demanda de las 21:40.

### 1.2. Estructura de generación

¿Y de dónde salen todos esos gigawatios de la figura anterior? De muchos sitios y de muchas tecnologías diferentes. Podemos realizar una llamada similar para obtener estos datos, obteniendo una estructura cuyos campos son los indicados en [esta tabla](https://demanda.ree.es/movil/peninsula/demanda/tablas/2):

```matlab
%% Generation structure
%  Fields: https://demanda.ree.es/movil/peninsula/demanda/tablas/2
try
    demand = urlread(['https://demanda.ree.es/WSvisionaMovilesPeninsula
        Rest/resources/demandaGeneracionPeninsula?callback=angular.callbacks._2
        &curva=DEMANDA
        &fecha=' day]);
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
```

En el siguiente gráfico se agrupan las más importantes, y cómo su aportación relativa al total varía a lo largo del día para sumar la potencia demandada por el país:

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g22015-08-01.png" alt=""></figure>

Sí, hay momentos en los que el gráfico empieza en negativo. Esto se debe a los intercambios internacionales, mediante los cuales España vende energía a nuestros vecinos. También es apreciable cómo ciertes fuentes son muy constantes (nuclear), como otras son más erráticas (eólica) y como otras ''siguen'' la demanda (hidroeléctrica). Esto se observa mejor en el gráfico siguiente, en el que no se apilan las curvas:

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g32015-08-01.png" alt=""></figure>

Mientras algunas fuentes son constantes y aportan una potencia de base, el viento hace más o menos lo que quiere y la solar sigue fielmente el ciclo del astro rey, la hidroeléctrica principalmente, así como las centrales térmicas de carbón, van variando su potencia para igualar la demanda del sistema. 

Se aprecia en este gráfico la necesidad de disponer de fuentes de energía estables que complementen las variaciones de las renovables que dependen del tiempo, así como de fuentes ''ágiles'' que permitan variar rápidamente su potencia para seguir la demanda. Esta relación con la demanda total la podemos ver mejor calculando el coeficiente de correlación:

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g42015-08-01.png" alt=""></figure>

Los coeficientes más próximos a 1 corresponden al carbón, ciclo combinado e hidroeléctrica, mientras que la energía solar está más próxima a 0.5 y la eólica no tiene nada que ver con la demanda. En el caso de la nuclear, al ser prácticamente constante, tampoco presenta correlación.

> Nota curiosa: el coeficiente del intercambio energético con Baleares es exactamente -1, pues consumen electricidad siguiendo el mismo patrón con que se vive en la Península. Canarias por otra parte dispone de sus propios generadores.

### 1.3. Precio

Mediante la [función propuesta](https://gist.github.com/JorgeGT/90600572df235b896611) también se puede acceder a los distintos precios a los que el pequeño consumidor (&lt;10 kW contratados) debe pagar la energía. Esta llamada es un poco diferente a las demás; en lugar de una estructura de datos obtenemos un vector de datos para cada tarifa, así como el vector de tiempos correspondiente:

```matlab
%% Price for small consumers
try
    price = urlread(['http://www.esios.ree.es/Solicitar?fileName=PVPC_CURV_DD_'
        datestr(datenum(day),'YYYYmmDD') '&fileType=txt&idioma=es']);
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
    priceGen = 0; priceNoc = 0; priceVhc = 0; tsPric = 0;
end
```

Graficamos a continuación el precio diario del megawatio para las distintas tarifas disponibles para el pequeño consumidor, comparados con la demanda total:

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g52015-08-01.png" alt=""></figure>

> Una idea obvia: leer el precio previsto cada día y poner en marcha los electrodomésticos según convenga, idealmente mediante algún sistema automático tipo Raspberry Pi

## 2. Evolución temporal

A partir de la función con la que obtenemos los datos diarios, es trivial construir un bucle que vaya guardando en una matriz los datos diarios de un periodo de tiempo determinado. Por ejemplo de un año completo:

```matlab
%% Temporal loop
dias = datenum('2014-08-01'):datenum('2015-08-01');
data = zeros(18,dias(end)-dias(1));
for i = 1:dias(end)-dias(1)+1
    try
        dia = datestr(dias(i),'YYYY-mm-DD');
        disp(['Day ' dia ' | ' num2str(round(100*i/(dias(end)-dias(1)+1))) 
              '% completed'])
        
        [tsDem,dem,tsPrev,prevision,tsPrec,precio,~,~] = getREEData(dia);
        
        dem = struct2cell(dem)';
        dem = double(cell2mat(dem(:,2:end)));
        
        data(1:15,i) = mean(dem)';
        data(16,i)   = mean([prevision.pre]);
        data(17,i)   = mean([prevision.pro]);
        data(18,i)   = mean(precio);
    catch error
        disp('Oops!')
    end
end
```

> Precaución: aunque las llamadas son ligeras y rápidas conviene no abusar demasiado para no sobrecargar la página de REE

Una vez tenemos recopilados los datos de todo un año, podemos realizar un análisis similar a los anteriores, pero esta vez considerando variaciones temporales más amplias.

### 2.1. Estructura de generación

Por ejemplo, apilando las distintas fuentes de energía para cada día tenemos el siguiente gráfico (hay unos días con errores, se muestran en blanco):

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g62015-08-01.png" alt=""></figure>

Podemos apreciar como la energía aportada por las centrales nucleares es muy constante a lo largo del año, mientras que otras son mucho más variables: la solar baja mucho en invierno, pero durante ese período la eólica se incrementa. 

Aquí tenemos el global de cómo se ha generado la energía consumida durante ese año (de agosto de 2014 a agosto de 2015):

<img width=42% src="http://wechoosethemoon.es/assets/img/posts/REE_tarta.png" alt=""/>

### 2.2. Precio

¿Y cuánto nos cuesta? Si graficamos el precio de la tarifa normal (2.0 A) a lo largo de esos 12 meses comprobamos que hay períodos, sobre todo de octubre a mayo, en los cuales la variabilidad de precio de un día a otro aumenta considerablemente. De mayo a septiembre hay menos variabilidad, aunque desgraciadamente el precio se mantiene alto. La media en este periodo ha sido de unos 12.16 ct./kW: 

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g72015-08-01.png" alt=""></figure>

### 2.3. Acontecimientos relevantes

Por último, las series temporales largas nos permiten detectar puntos que se salen de lo habitual. Como muestra, dos botones:

#### 2.3.1. Paradas nucleares

Hemos visto anteriormente que la energía nuclear es muy constante a lo alrgo del año. Pero si graficamos esta información por separado podemos observar, aparte de los "escalones" en que cambia la potencia de alguna central, ciertos picos súbitos de uno o dos días. Podemos tratar de detectarlos automáticamente mediante la función `findpeaks()`:

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g8.png" alt=""></figure>

Si nos fijamos en el pico del día 3 de febrero y consultamos la página del Consejo de Seguridad Nuclear, podemos efectivamente comprobar que el pico se debe a una aprada no programa de la central Vandellós II. Tal y como consta en el [informe](https://www.csn.es/documents/10182/860789/03.02.15%20-%20Vandellós%20II%20(Tarragona)%20-%20INES%200): 

*''A las 15:00 horas se ha producido la parada automática del reactor debido a la pérdida de la conexión eléctrica con la línea de 400 KV. En el momento del suceso había fuertes vientos en la zona.''*

#### 2.3.2. Huelgas generales

Comentábamos anteriormente la precisión que tenía el modelo de previsión de demanda de REE. Sin embargo, hay días que se salen de la pauta: un ejemplo claro es el de las huelgas generales, en los que el paro provoca un menor consumo que se aleja de lo previsto. Podemos calcular este error relativo `E` para todos los días:

```
E =  (Energia Consumida Total - Energia Programada)/Energia Programada*100 
```

Lo cual resulta en el siguiente gráfico, donde se aprecia perfectamente que la discrepancia es normalmente de aproximadamente un +-1%, mientras que el día 14 de noviembre de 2012, última huelga general convocada en España, el consumo cayó hasta un 10% frente a un día normal.

<figure><img src="http://wechoosethemoon.es/assets/img/posts/REE_g9.png" alt=""></figure>

> La gente de [Politikon](http://politikon.es/14N/) hizo un interesante seguimiento del 14N a través del consumo en tiempo real, aunque ellos programan en Python! 

## 3. Conclusiones

La información abierta de REE nos permite realizar multitud de sencillos estudios que sin embargo arrojan bastante información sobre nuestro entorno: el nivel de incidencia de una huelga, la frecuencia de fallos en los reactores nucleares, programar estrategias para reducir nuestro gasto eléctrico, observar el funcionamiento de las distintas tecnologías y formarnos una opinión informada sobre su balance, etc. Esperemos que esta tendencia de compartir la información con la ciudadanía continúe!
