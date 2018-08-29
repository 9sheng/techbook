# datetime函数

## c 标准库
```cpp
// 时间字符串转换成UNIX时间戳
struct tm tm;
if (strptime("2016-01-21 17:38:12", "%F %T", &tm) != NULL) {
    time_t ts = mktime(&tm);
}

// UNIX时间戳转换成时间字符串
// NOTE: localtime is not thread safe, use localtime_r instead
char buff[32];
strftime(buff, sizeof(buff), "%F %T", localtime(&ts));
```
## boost::posix_time
```cpp
#include <boost/date_time/posix_time/posix_time.hpp>
using namespace boost::posix_time;

// 构造
ptime t(time_from_string("2002-01-20 23:59:59.000"));
ptime t(from_iso_string("20020131T235959"));
ptime from_time_t(time_t t);

// 字符串转换
std::string to_simple_string(ptime);       // 2002-Jan-01 10:00:01.123456789
std::string to_iso_string(ptime);          // 20020131T100001,123456789
std::string to_iso_extended_string(ptime); // 2002-01-31T10:00:01,123456789
```

## boost::gregorian
```cpp
#include <boost/date_time/gregorian/gregorian.hpp>
using namespace boost::gregorian;

// 构造
date d(from_simple_string("2016-12-13"));
date d(from_string("2002/1/25"));
date d(from_undelimited_string("20020125"));

// 字符串转换
std::string to_simple_string(date d);       // "2002-Jan-01"
std::string to_iso_string(date d);          // "20020131"
std::string to_iso_extended_string(date d); // "2002-01-31"
```
