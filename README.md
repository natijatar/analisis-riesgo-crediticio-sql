#  Análisis de Riesgo Crediticio y Optimización de Políticas de Admisión

## Objetivo
El propósito de este análisis es evaluar una cartera de **32,581 solicitudes de crédito** utilizando SQL. El fin es identificar patrones críticos de comportamiento que disparen la tasa de mora (Default) y proponer reglas de negocio analíticas para mejorar los controles de admisión.

---


## 1)Identificación de Insights de Riesgo

Para entender cuáles son las variables demográficas y de negocio que más impactan en la probabilidad de impago, analizamos el comportamiento de mora cruzando la variable objetivo `loan_status` (donde `1` representa mora/default) con la situación habitacional y el destino del fondo solicitado.

###  Impacto de la Situación Habitacional en la Mora
Ejecutamos una consulta para evaluar si el tipo de vivienda del solicitante influye en la tasa de default de la cartera. Los clientes pueden estar alquilando, pagando un préstamo hipotecario (mortgage) o pueden ser dueños. 

```sql
SELECT 
    person_home_ownership AS tipo_vivienda,
    COUNT(*) AS total_clientes,
    ROUND(AVG(loan_status) * 100, 2) AS tasa_mora_porcentaje
FROM credit_risk
GROUP BY person_home_ownership
ORDER BY tasa_mora_porcentaje DESC;

#### Resultados obtenidos 

|tipo_vivienda|total_clientes|tasa_mora_porcentaje|
|-------------|--------------|--------------------|
|RENT|16446|31.57|
|OTHER|107|30.84|
|MORTGAGE|13444|12.57|
|OWN|2584|7.47|

Al observar estos resultados, notamos que hay una brecha de riesgo entre los solicitantes que alquilan (31.57% de mora) y entre los que son propietarios (7.47%). Considerando que el grupo que alquila concentra la mayoría de las solicitudes, estamos expuestos a pérdidas altas. Para poder mitigar esto, se debería quizá exigir ingresos más altos para otorgar el crédito, o prestar montos menores. 

###  Impacto del Destino del Crédito en la Mora

También analizamos el comportamiento de pago agrupando las solicitudes según la finalidad declarada del préstamo (`loan_intent`) para entender en qué actividades se concentran los mayores niveles de default.

```sql
SELECT 
    loan_intent AS destino_credito,
    COUNT(*) AS total_solicitudes,
    ROUND(AVG(loan_status) * 100, 2) AS tasa_mora_porcentaje
FROM credit_risk
GROUP BY loan_intent
ORDER BY tasa_mora_porcentaje DESC;

#### Resultados obtenidos 

|destino_credito|total_solicitudes|tasa_mora_porcentaje|
|---------------|-----------------|--------------------|
|DEBTCONSOLIDATION|5212|28.59|
|MEDICAL|6071|26.7|
|HOMEIMPROVEMENT|3605|26.1|
|PERSONAL|5521|19.89|
|EDUCATION|6453|17.22|
|VENTURE|5719|14.81|

En el cuadro observamos que los créditos con mayor tasa de default son los que fueron utilizados para consolidar deudas ya existentes (DEBTCONSOLIDATION), seguido por las emergencias médicas. Por otro lado, los préstamos para educacion o emprendimientos personales presentan perfiles de pago más sanos, podríamos pensar que estas inversiones de capital tuvieron luego un retorno positivo, a diferencia de los motivos mencionados previamente. 


## 2) Mejora de controles

Se analizará qué porcentaje del sueldo comprometen los clientes que entran en default, comparado a los que no. En función de eso, buscamos diseñar algún límite que ayude a mitigar posibles pérdidas


```sql
SELECT 
    loan_status AS estado_pago,
    COUNT(*) AS total_casos,
    ROUND(AVG(loan_percent_income) * 100, 2) AS porcentaje_ingreso_comprometido_promedio
FROM credit_risk
GROUP BY loan_status;

#### Resultados obtenidos 

|estado_pago|total_casos|porcentaje_ingreso_comprometido_promedio|
|-----------|-----------|----------------------------------------|
|0|25473|14.88|
|1|7108|24.69|

En la tabla podemos ver una diferencia crítica en el comportamiento de pago según el nivel de endeudamiento. Los clientes que no entran default comprometen en promedio el 14.88% de sus ingresos en la cuota, mientras que los que caen en mora comprometen casi un 25%.
Podríamos sugerirle a la entidad que otorga los créditos que imponga algún límite, como por ejemplo rechazar las solicitudes donde la cuota supera el 20% del ingreso declarado. 


## 3) Automatización de reportes

Ahora queremos armar un mecanismo de control y de alerta, que nos detecte aquellos clientes de la cartera con ingresos bajos que superan el 30% de mora (suponemos el 30% como el máximo tolerable). Al detectarlos, se podrían ejecutar medidas mitigatorias proactivas antes de que afecten la rentabilidad global de la cartera. 

Para observar cual es el monto de ingreso a partir del cual lo consideramos bajo, buscamos el percentil 25. 


|percentil_25|percentil_50_mediana|ingreso_promedio|
|------------|--------------------|----------------|
|38500.0|55000.0|66074.84846996715|


Nos da $38500, utiliaré $40000 para redondear.


```sql

SELECT 
    person_home_ownership AS vivienda,
    loan_intent AS destino,
    COUNT(*) AS total_alertas,
    ROUND(AVG(loan_int_rate), 2) AS tasa_interes_promedio,
    ROUND(AVG(loan_status) * 100, 2) AS tasa_mora_porcentaje
FROM credit_risk
WHERE person_income < 40000 
GROUP BY person_home_ownership, loan_intent
HAVING AVG(loan_status) > 0.30 
ORDER BY tasa_mora_porcentaje DESC;


#### Resultados obtenidos 

|vivienda|destino|total_alertas|tasa_interes_promedio|tasa_mora_porcentaje|
|--------|-------|-------------|---------------------|--------------------|
|RENT|HOMEIMPROVEMENT|355|12.87|100.0|
|OTHER|MEDICAL|3|13.03|100.0|
|OTHER|HOMEIMPROVEMENT|1|12.53|100.0|
|OTHER|DEBTCONSOLIDATION|5|9.14|80.0|
|OTHER|EDUCATION|6|12.19|66.67|
|RENT|DEBTCONSOLIDATION|1027|11.52|51.8|
|OTHER|PERSONAL|4|12.0|50.0|
|OWN|DEBTCONSOLIDATION|40|13.39|50.0|
|RENT|PERSONAL|985|11.72|48.93|
|RENT|VENTURE|930|11.52|43.44|
|RENT|MEDICAL|1434|11.43|41.84|
|RENT|EDUCATION|1151|11.24|41.18|
|MORTGAGE|HOMEIMPROVEMENT|234|10.56|34.19|
|MORTGAGE|MEDICAL|290|10.81|32.07|

Observamos todas las combinaciones de tipo de vivienda junto con el destino del crédito. Filtramos únicamente las que tienen un ingreso menor a $40000 y además las que en promedio entraron un 30% o más en default.
Al realizar esto, pudimos encontrar los grupos más riesgosos, siendo el líder el "RENT + HOMEIMPROVEMENT". Este grupo incluye los clientes que son inquilinos y que pidieron el préstamo para refaccionar su vivienda. Este combo mucho sentido no tiene, dado que implica que una persona de bajos recursos pidió un préstamo para refaccionar una propiedad que no es suya.

#### Cambios propuestos para el motor de aprobación:

Con estos datos, podríamos ajustar las reglas de admisión automáticas para frenar las pérdidas. Las propuestas concretas son:

1. **Rechazo automático para RENT + HOMEIMPROVEMENT:** Si un inquilino gana menos de $40,000 y pide plata para refaccionar, la solicitud se debe rechazar al instante. Históricamente, el 100% de estos casos terminó en mora, por lo que no tiene sentido financiero aprobarlos.
2. **Filtros más estrictos para consolidar deudas:** Para los inquilinos de ingresos bajos que quieren unificar deudas (`DEBTCONSOLIDATION`), hay que eliminar la aprobación automática o, por lo menos, recortar el monto aprobado a la mitad. Más de la mitad de ellos (51.8%) termina defaulteando.
3. **Monitoreo con alertas mensuales:** Dejar programada esta consulta SQL para que corra una vez al mes sobre los nuevos créditos. Así, se puede detectar a tiempo si aparecen nuevos grupos de clientes que cruzan el límite tolerable del 30% de mora.

## Conclusión General 

Se pudo demostrar cómo el análisis de datos mediante SQL permite transformar registros transaccionales crudos en decisiones estratégicas para mitigar el riesgo crediticio

1. **Fase A:** Identificamos que el riesgo no es uniforme. La situación habitacional (alquiler) y destinos específicos de fondos (como consolidar deudas o refaccionar) actúan como aceleradores del default.

2. **Fase B:** Se propuso un límite objetivo de capacidad de pago (máximo 20% del ingreso destinado a la cuota), basándonos en que los clientes que entran en mora comprometen, en promedio, casi un 25% de su sueldo.

3. **Fase C:** Se diseñó un sistema de alerta temprana para aislar de forma automática a los segmentos más vulnerables de bajos ingresos que superan nuestra tolerancia máxima de mora (30%). Esto permitió detectar nichos críticos (como inquilinos que consolidan deudas, con un 51.8% de mora) que requieren bloqueo inmediato o reestructuración de condiciones.


Al implementar estas reglas en el motor de admisión y automatizar el monitoreo con las consultas diseñadas:
* Se podría reducir la pérdida esperada al evitar la aprobación de perfiles con probabilidad de default superior al 50%.
* Se optimiza la eficiencia operativa, que ahora cuenta con un "semáforo" automatizado en lugar de tener que procesar bases de datos manualmente.

De esta manera, podemos decir que protegemos la rentabilidad de la cartera, garantizando una expansión sostenible del portafolio en perfecta sintonía con el perfil de riesgo aceptable.

