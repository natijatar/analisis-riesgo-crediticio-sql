
-- PROYECTO: Optimización de Políticas de Admisión y Control de Riesgo Crediticio
-- AUTOR: Natalia Jatar
-- OBJETIVO: Voy a analizar una cartera de 32.500 solicitudes de crédito para ver si podemos
--           identificar patrones de mora y proponer mejoras en los controles.


CREATE TABLE IF NOT EXISTS credit_risk AS 
SELECT * FROM read_csv('C:/Users/natal/OneDrive/Documentos/datasets SQL/credit_risk_dataset.csv');

SELECT * FROM credit_risk LIMIT 10;

-- 1) IDENTIFICAR INSIGHTS DE RIESGO
-- Objetivo: Determinar qué variables demográficas y de negocio disparan la mora.
--

--Aquí consultaremos cual es la tasa de mora según la situación habitacional de cada cliente--
SELECT 
    person_home_ownership AS tipo_vivienda,
    COUNT(*) AS total_clientes,
    ROUND(AVG(loan_status) * 100, 2) AS tasa_mora_porcentaje
FROM credit_risk
GROUP BY person_home_ownership
ORDER BY tasa_mora_porcentaje DESC;

--Ahora observaremos cual es la tasa de mora en función del destino del crédito

SELECT 
    loan_intent AS destino_credito,
    COUNT(*) AS total_solicitudes,
    ROUND(AVG(loan_status) * 100, 2) AS tasa_mora_porcentaje
FROM credit_risk
GROUP BY loan_intent
ORDER BY tasa_mora_porcentaje DESC;

-- 2) Mejora de controles
-- Objetivo: Analizar qué porcentaje del sueldo comprometen los clientes que entran en default, comparado a los que no
--           En función de eso, buscamos diseñar algún límite            

SELECT 
    loan_status AS estado_pago, -- 0 = Al día, 1 = Mora/Default
    COUNT(*) AS total_casos,
    ROUND(AVG(loan_percent_income) * 100, 2) AS porcentaje_ingreso_comprometido_promedio
FROM credit_risk
GROUP BY loan_status;


-- 3) Automnatización de reportes

-- Objetivo: queremos armar un mecanismo de control y de alerta, que nos detecte aquellos clientes de la cartera con ingresos
---          bajos que superan el 30% de mora (suponemos el 30% como el máximo tolerable). Al detectarlos, de podrían ejecutar
---          medidas mitigatorias proactivas antes de que afecten la rentabilidad global de la cartera. 

--- Para observar cual es el monto de ingreso, buscamos el percentil 25. 

SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY person_income) AS percentil_25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY person_income) AS percentil_50_mediana,
    AVG(person_income) AS ingreso_promedio
FROM credit_risk;

--Nos da $38500, utiliaré $40000 para redondear

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

















