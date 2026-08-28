import 'package:timeago/timeago.dart' as timeago;

/// Custom Amharic Lookup Messages for `timeago` package
class AmMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'በፊት';
  @override
  String suffixFromNow() => 'በኋላ';
  @override
  String lessThanOneMinute(int seconds) => 'ከጥቂት ሴኮንዶች';
  @override
  String aboutAMinute(int minutes) => 'ከአንድ ደቂቃ';
  @override
  String minutes(int minutes) => 'ከ $minutes ደቂቃ';
  @override
  String aboutAnHour(int minutes) => 'ከአንድ ሰዓት';
  @override
  String hours(int hours) => 'ከ $hours ሰዓት';
  @override
  String aDay(int hours) => 'ከአንድ ቀን';
  @override
  String days(int days) => 'ከ $days ቀን';
  @override
  String aboutAMonth(int days) => 'ከአንድ ወር';
  @override
  String months(int months) => 'ከ $months ወር';
  @override
  String aboutAYear(int year) => 'ከአንድ ዓመት';
  @override
  String years(int years) => 'ከ $years ዓመት';
  @override
  String wordSeparator() => ' ';
}

/// Custom Afaan Oromo Lookup Messages for `timeago` package
class OmMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'dura';
  @override
  String suffixFromNow() => 'boddaa';
  @override
  String lessThanOneMinute(int seconds) => 'sekondii muraasa';
  @override
  String aboutAMinute(int minutes) => 'daqiiqaa tokko';
  @override
  String minutes(int minutes) => 'daqiiqaa $minutes';
  @override
  String aboutAnHour(int minutes) => 'saa\'aatii tokko';
  @override
  String hours(int hours) => 'saa\'aatii $hours';
  @override
  String aDay(int hours) => 'guyyaa tokko';
  @override
  String days(int days) => 'guyyaa $days';
  @override
  String aboutAMonth(int days) => 'ji\'a tokko';
  @override
  String months(int months) => 'ji\'a $months';
  @override
  String aboutAYear(int year) => 'waggaa tokko';
  @override
  String years(int years) => 'waggaa $years';
  @override
  String wordSeparator() => ' ';
}

/// Custom Tigrinya Lookup Messages for `timeago` package
class TiMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'ቅድሚ ሕጂ';
  @override
  String suffixFromNow() => 'ድሕሪ ሕጂ';
  @override
  String lessThanOneMinute(int seconds) => 'ውሑዳት ካልኢታት';
  @override
  String aboutAMinute(int minutes) => 'ሓደ ደቒቓ';
  @override
  String minutes(int minutes) => '$minutes ደቒቓ';
  @override
  String aboutAnHour(int minutes) => 'ሓደ ሰዓት';
  @override
  String hours(int hours) => '$hours ሰዓት';
  @override
  String aDay(int hours) => 'ሓደ መዓልቲ';
  @override
  String days(int days) => '$days መዓልቲ';
  @override
  String aboutAMonth(int days) => 'ሓደ ወርሒ';
  @override
  String months(int months) => '$months ወርሒ';
  @override
  String aboutAYear(int year) => 'ሓደ ዓመት';
  @override
  String years(int years) => '$years ዓመት';
  @override
  String wordSeparator() => ' ';
}

/// Custom Somali Lookup Messages for `timeago` package
class SoMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'kahor';
  @override
  String suffixFromNow() => 'kadib';
  @override
  String lessThanOneMinute(int seconds) => 'ilbiriqsiyo yar';
  @override
  String aboutAMinute(int minutes) => 'hal daqiiqo';
  @override
  String minutes(int minutes) => 'daqiiqo $minutes';
  @override
  String aboutAnHour(int minutes) => 'hal saac';
  @override
  String hours(int hours) => 'saacadood $hours';
  @override
  String aDay(int hours) => 'hal maalin';
  @override
  String days(int days) => 'maalmo $days';
  @override
  String aboutAMonth(int days) => 'hal bil';
  @override
  String months(int months) => 'bilood $months';
  @override
  String aboutAYear(int year) => 'hal sano';
  @override
  String years(int years) => 'sano $years';
  @override
  String wordSeparator() => ' ';
}

/// Registers Amharic, Afaan Oromo, Tigrinya, and Somali locales with timeago.
void setupTimeAgoLocales() {
  timeago.setLocaleMessages('am', AmMessages());
  timeago.setLocaleMessages('am_short', AmMessages());
  timeago.setLocaleMessages('om', OmMessages());
  timeago.setLocaleMessages('om_short', OmMessages());
  timeago.setLocaleMessages('ti', TiMessages());
  timeago.setLocaleMessages('ti_short', TiMessages());
  timeago.setLocaleMessages('so', SoMessages());
  timeago.setLocaleMessages('so_short', SoMessages());
}
