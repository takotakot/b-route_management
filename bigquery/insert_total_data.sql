-- Template for insert_total_data procedure body
-- Variables: dataset_id, table_id
BEGIN
  DECLARE min_timestamp, max_timestamp TIMESTAMP;

  SET (min_timestamp, max_timestamp) = (
    SELECT AS STRUCT
      MIN(ts) AS min_ts
      , MAX(ts) AS max_ts
    FROM
      UNNEST(insert_values) AS dat
  );

  BEGIN TRANSACTION;
  MERGE INTO `${dataset_id}.${table_id}` AS target
  USING (
    WITH cte_values AS (
      SELECT insert_values AS data_array
    )

    SELECT
      dat.point_id
      , dat.ts
      , ANY_VALUE(CAST(dat.total_power_kwh AS NUMERIC)) AS power
    FROM
      cte_values
    , UNNEST(data_array) AS dat
    GROUP BY point_id, ts
  ) AS source
    ON
      target.timestamp BETWEEN min_timestamp AND max_timestamp
      AND target.point_id = source.point_id
      AND target.timestamp = source.ts
  WHEN MATCHED THEN
    UPDATE SET
      target.total_power_kwh = source.power
  WHEN NOT MATCHED THEN
    INSERT (point_id, timestamp, total_power_kwh)
    VALUES (source.point_id, source.ts, source.power);
  COMMIT TRANSACTION;
END
