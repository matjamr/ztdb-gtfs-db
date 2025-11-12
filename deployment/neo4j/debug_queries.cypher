// See which Calendar entries would match and what day they expect
WITH '2025-11-09' AS travelDateString,
     date('2025-11-09') AS travelDate
WITH travelDate,
     toString(travelDate.year) +
     CASE WHEN travelDate.month < 10 THEN '0' + toString(travelDate.month) ELSE toString(travelDate.month) END +
     CASE WHEN travelDate.day < 10 THEN '0' + toString(travelDate.day) ELSE toString(travelDate.day) END AS travelDateYYYYMMDD,
     (duration.between(date('1970-01-05'), travelDate).days % 7) AS dayOfWeek

MATCH (c:Calendar)
  WHERE travelDateYYYYMMDD >= c.start_date
  AND travelDateYYYYMMDD <= c.end_date
RETURN
  c.service_id,
  c.start_date,
  dayOfWeek,
  c.monday, c.tuesday, c.wednesday, c.thursday,
  c.friday, c.saturday, c.sunday,
  CASE dayOfWeek
    WHEN 0 THEN c.monday
    WHEN 1 THEN c.tuesday
    WHEN 2 THEN c.wednesday
    WHEN 3 THEN c.thursday
    WHEN 4 THEN c.friday
    WHEN 5 THEN c.saturday
    WHEN 6 THEN c.sunday
    END AS matches
  LIMIT 20;

// Check calendar service patterns
MATCH (c:Calendar)
RETURN c.service_id, c.monday, c.tuesday, c.wednesday, c.thursday,
       c.friday, c.saturday, c.sunday, c.start_date, c.end_date
  LIMIT 10;