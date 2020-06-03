CREATE OR REPLACE FUNCTION pretty_metric(p_number        IN NUMBER,
                                         p_rounding_type IN CHAR DEFAULT 'R',
                                         p_round_to      IN NUMBER DEFAULT 1,
                                         p_before        IN VARCHAR2 DEFAULT NULL,
                                         p_after         IN VARCHAR2 DEFAULT NULL,
                                         p_scale         IN VARCHAR2 DEFAULT 'SI')
    RETURN VARCHAR2 IS
    l_divisor   NUMBER := 1000;
    l_magnitude NUMBER;
    l_suffix    VARCHAR2(100);
BEGIN
    IF UPPER(TRIM(p_scale)) LIKE 'BINARY%' THEN
        l_divisor := 1024; --1024 bytes in a KiB
    END IF;

    l_magnitude := FLOOR(LOG(l_divisor, p_number));
    l_suffix    := APEX_UTIL.string_to_table(CASE UPPER(TRIM(p_scale))
                                                 WHEN 'SI' THEN 'y,z,a,f,p,n,µ,m,,K,M,G,T,P,E,Z,Y'
                                                 WHEN 'SI-LONG' THEN 'yocto,zepto,atto,femto,pico,nano,micro,milli,,kilo,mega,giga,tera,peta,exa,zetta,yotta'
                                                 WHEN 'BINARY' THEN ',,,,,,,,B,KiB,MiB,GiB,TiB,PiB,EiB,ZiB,YiB'
                                                 WHEN 'BINARY-LONG' THEN ',,,,,,,,bytes,kibibytes,mebibytes,gibibytes,tebibytes,pebibytes,exbibytes,zebibytes,yobibytes'
                                                 WHEN 'EN-US' THEN ',,,,,,,,,K,M,B,t,q,Q,s,S,o,n,d'
                                                 WHEN 'EN-US-LONG' THEN ',,,,,,,,,thousand,million,billion,trillion,quadrillion,quintillion,sextillion,septillion,octillion,nonillion,decillion'
                                                 ELSE p_scale
                                             END,
                                             ',')(l_magnitude + 9);

    --if p_scale is entered in InitCap, suffix is also InitCapped
    IF p_scale = INITCAP(p_scale) THEN
        l_suffix := INITCAP(l_suffix);
    END IF;

    RETURN    p_before
           || CASE p_rounding_type
                  WHEN 'F' THEN FLOOR(p_number / POWER(l_divisor, l_magnitude) / p_round_to) * p_round_to
                  WHEN 'R' THEN ROUND(p_number / POWER(l_divisor, l_magnitude) / p_round_to) * p_round_to
                  WHEN 'C' THEN CEIL(p_number / POWER(l_divisor, l_magnitude) / p_round_to) * p_round_to
                  ELSE p_number / POWER(l_divisor, l_magnitude)
              END
           || CASE
                  WHEN SUBSTR(p_scale, 1, 1) = ' ' --if p_scale starts with a space or ends with 'LONG', add a space before the suffix
                    OR UPPER(p_scale) LIKE '%LONG' THEN
                      ' '
              END
           || l_suffix
           || p_after;
END pretty_metric;

/* SAMPLE USAGE */
SELECT pretty_metric(p_number => 123456000000)                                         simple, --123G
       pretty_metric(p_number => 123456, p_round_to => 0.01, p_after => 'B')           bytes_decimal, --123.46KB
       pretty_metric(p_number   => 123456,
                     p_round_to => 0.01,
                     p_after    => 'bytes',
                     p_scale    => 'si-long')                                          bytes_decimal_long, --123.46 kilobytes
       pretty_metric(p_number => 123456, p_round_to => 0.01, p_scale => 'binary')      bytes_binary, --120.56KiB
       pretty_metric(p_number => 123456, p_round_to => 0.01, p_scale => 'Binary-Long') bytes_binary_long, --120.56 Kibibytes
       pretty_metric(p_number   => 2543947000,
                     p_round_to => 0.1,
                     p_before   => '$',
                     p_scale    => 'En-Us-Long')                                       english_long, --$2.5 Billion
       pretty_metric(p_number   => 2543947000,
                     p_round_to => 0.1,
                     p_before   => '$',
                     p_scale    => 'en-us')                                            english_short, --$2.5B
       pretty_metric(p_number => 5000, p_round_to => 0.01, p_after => 'm')             distance_big, --5Km
       pretty_metric(p_number => 0.0000025, p_round_to => 0.01, p_after => 'm')        distance_small, --2.5µm
       pretty_metric(p_number   => 0.0000000025,
                     p_round_to => 0.01,
                     p_after    => 'seconds',
                     p_scale    => 'Si-Long')                                          seconds_long, --2.5 Nanoseconds
       pretty_metric(p_number   => 0.0000000025,
                     p_round_to => 0.01,
                     p_after    => 's',
                     p_scale    => 'si')                                               seconds_short, --2.5ns
       pretty_metric(p_number => 128456789, p_rounding_type => 'None')                 unrounded, --128.456789M
       pretty_metric(p_number => 128456789, p_rounding_type => 'C', p_round_to => 50)  ceiling_50, --150M
       pretty_metric(p_number => 128456789, p_round_to => 50)                          rounded_50, --150M
       pretty_metric(p_number        => 128456789,
                     p_rounding_type => 'F',
                     p_round_to      => 50,
                     p_scale         => 'SI')                                          floor_50 --100M
  FROM DUAL;
