SELECT
  * EXCEPT (timestamp)
  -- , DATETIME(timestamp , 'Asia/Tokyo') AS datetime_jst
  , TIMESTAMP_ADD(timestamp, INTERVAL 9 HOUR) AS timestamp_jst
FROM
  `${dataset_id}.${table_id}`
