//! Internationalization (i18n) support for Craft
//! Provides cross-platform abstractions for localization, number formatting,
//! date/time formatting, pluralization, and text direction.

const std = @import("std");

/// Language code (ISO 639-1)
pub const LanguageCode = enum {
    en, // English
    es, // Spanish
    fr, // French
    de, // German
    it, // Italian
    pt, // Portuguese
    zh, // Chinese
    ja, // Japanese
    ko, // Korean
    ar, // Arabic
    ru, // Russian
    hi, // Hindi
    tr, // Turkish
    nl, // Dutch
    pl, // Polish
    vi, // Vietnamese
    th, // Thai
    id, // Indonesian
    ms, // Malay
    sv, // Swedish
    da, // Danish
    no, // Norwegian
    fi, // Finnish
    he, // Hebrew
    uk, // Ukrainian
    cs, // Czech
    el, // Greek
    ro, // Romanian
    hu, // Hungarian
    unknown,

    pub fn toString(self: LanguageCode) []const u8 {
        return switch (self) {
            .en => "en",
            .es => "es",
            .fr => "fr",
            .de => "de",
            .it => "it",
            .pt => "pt",
            .zh => "zh",
            .ja => "ja",
            .ko => "ko",
            .ar => "ar",
            .ru => "ru",
            .hi => "hi",
            .tr => "tr",
            .nl => "nl",
            .pl => "pl",
            .vi => "vi",
            .th => "th",
            .id => "id",
            .ms => "ms",
            .sv => "sv",
            .da => "da",
            .no => "no",
            .fi => "fi",
            .he => "he",
            .uk => "uk",
            .cs => "cs",
            .el => "el",
            .ro => "ro",
            .hu => "hu",
            .unknown => "und",
        };
    }

    pub fn englishName(self: LanguageCode) []const u8 {
        return switch (self) {
            .en => "English",
            .es => "Spanish",
            .fr => "French",
            .de => "German",
            .it => "Italian",
            .pt => "Portuguese",
            .zh => "Chinese",
            .ja => "Japanese",
            .ko => "Korean",
            .ar => "Arabic",
            .ru => "Russian",
            .hi => "Hindi",
            .tr => "Turkish",
            .nl => "Dutch",
            .pl => "Polish",
            .vi => "Vietnamese",
            .th => "Thai",
            .id => "Indonesian",
            .ms => "Malay",
            .sv => "Swedish",
            .da => "Danish",
            .no => "Norwegian",
            .fi => "Finnish",
            .he => "Hebrew",
            .uk => "Ukrainian",
            .cs => "Czech",
            .el => "Greek",
            .ro => "Romanian",
            .hu => "Hungarian",
            .unknown => "Unknown",
        };
    }

    pub fn fromString(code: []const u8) LanguageCode {
        if (std.mem.eql(u8, code, "en")) return .en;
        if (std.mem.eql(u8, code, "es")) return .es;
        if (std.mem.eql(u8, code, "fr")) return .fr;
        if (std.mem.eql(u8, code, "de")) return .de;
        if (std.mem.eql(u8, code, "it")) return .it;
        if (std.mem.eql(u8, code, "pt")) return .pt;
        if (std.mem.eql(u8, code, "zh")) return .zh;
        if (std.mem.eql(u8, code, "ja")) return .ja;
        if (std.mem.eql(u8, code, "ko")) return .ko;
        if (std.mem.eql(u8, code, "ar")) return .ar;
        if (std.mem.eql(u8, code, "ru")) return .ru;
        if (std.mem.eql(u8, code, "hi")) return .hi;
        if (std.mem.eql(u8, code, "tr")) return .tr;
        if (std.mem.eql(u8, code, "nl")) return .nl;
        if (std.mem.eql(u8, code, "pl")) return .pl;
        if (std.mem.eql(u8, code, "vi")) return .vi;
        if (std.mem.eql(u8, code, "th")) return .th;
        if (std.mem.eql(u8, code, "id")) return .id;
        if (std.mem.eql(u8, code, "ms")) return .ms;
        if (std.mem.eql(u8, code, "sv")) return .sv;
        if (std.mem.eql(u8, code, "da")) return .da;
        if (std.mem.eql(u8, code, "no")) return .no;
        if (std.mem.eql(u8, code, "fi")) return .fi;
        if (std.mem.eql(u8, code, "he")) return .he;
        if (std.mem.eql(u8, code, "uk")) return .uk;
        if (std.mem.eql(u8, code, "cs")) return .cs;
        if (std.mem.eql(u8, code, "el")) return .el;
        if (std.mem.eql(u8, code, "ro")) return .ro;
        if (std.mem.eql(u8, code, "hu")) return .hu;
        return .unknown;
    }
};

/// Region/country code (ISO 3166-1 alpha-2)
pub const RegionCode = enum {
    US, // United States
    GB, // United Kingdom
    CA, // Canada
    AU, // Australia
    DE, // Germany
    FR, // France
    ES, // Spain
    IT, // Italy
    PT, // Portugal
    BR, // Brazil
    MX, // Mexico
    CN, // China
    TW, // Taiwan
    HK, // Hong Kong
    JP, // Japan
    KR, // Korea
    IN, // India
    RU, // Russia
    SA, // Saudi Arabia
    AE, // UAE
    IL, // Israel
    TR, // Turkey
    NL, // Netherlands
    PL, // Poland
    SE, // Sweden
    NO, // Norway
    DK, // Denmark
    FI, // Finland
    unknown,

    pub fn toString(self: RegionCode) []const u8 {
        return switch (self) {
            .US => "US",
            .GB => "GB",
            .CA => "CA",
            .AU => "AU",
            .DE => "DE",
            .FR => "FR",
            .ES => "ES",
            .IT => "IT",
            .PT => "PT",
            .BR => "BR",
            .MX => "MX",
            .CN => "CN",
            .TW => "TW",
            .HK => "HK",
            .JP => "JP",
            .KR => "KR",
            .IN => "IN",
            .RU => "RU",
            .SA => "SA",
            .AE => "AE",
            .IL => "IL",
            .TR => "TR",
            .NL => "NL",
            .PL => "PL",
            .SE => "SE",
            .NO => "NO",
            .DK => "DK",
            .FI => "FI",
            .unknown => "ZZ",
        };
    }

    pub fn englishName(self: RegionCode) []const u8 {
        return switch (self) {
            .US => "United States",
            .GB => "United Kingdom",
            .CA => "Canada",
            .AU => "Australia",
            .DE => "Germany",
            .FR => "France",
            .ES => "Spain",
            .IT => "Italy",
            .PT => "Portugal",
            .BR => "Brazil",
            .MX => "Mexico",
            .CN => "China",
            .TW => "Taiwan",
            .HK => "Hong Kong",
            .JP => "Japan",
            .KR => "Korea",
            .IN => "India",
            .RU => "Russia",
            .SA => "Saudi Arabia",
            .AE => "United Arab Emirates",
            .IL => "Israel",
            .TR => "Turkey",
            .NL => "Netherlands",
            .PL => "Poland",
            .SE => "Sweden",
            .NO => "Norway",
            .DK => "Denmark",
            .FI => "Finland",
            .unknown => "Unknown",
        };
    }
};

/// Text direction
pub const TextDirection = enum {
    ltr, // Left-to-right
    rtl, // Right-to-left

    pub fn toString(self: TextDirection) []const u8 {
        return switch (self) {
            .ltr => "ltr",
            .rtl => "rtl",
        };
    }

    pub fn forLanguage(lang: LanguageCode) TextDirection {
        return switch (lang) {
            .ar, .he => .rtl,
            else => .ltr,
        };
    }

    pub fn isRtl(self: TextDirection) bool {
        return self == .rtl;
    }
};

/// Locale identifier combining language and region
pub const Locale = struct {
    language: LanguageCode,
    region: RegionCode,
    script: ?[]const u8,

    pub const en_US = Locale{ .language = .en, .region = .US, .script = null };
    pub const en_GB = Locale{ .language = .en, .region = .GB, .script = null };
    pub const es_ES = Locale{ .language = .es, .region = .ES, .script = null };
    pub const es_MX = Locale{ .language = .es, .region = .MX, .script = null };
    pub const fr_FR = Locale{ .language = .fr, .region = .FR, .script = null };
    pub const de_DE = Locale{ .language = .de, .region = .DE, .script = null };
    pub const it_IT = Locale{ .language = .it, .region = .IT, .script = null };
    pub const pt_BR = Locale{ .language = .pt, .region = .BR, .script = null };
    pub const pt_PT = Locale{ .language = .pt, .region = .PT, .script = null };
    pub const zh_CN = Locale{ .language = .zh, .region = .CN, .script = null };
    pub const zh_TW = Locale{ .language = .zh, .region = .TW, .script = null };
    pub const ja_JP = Locale{ .language = .ja, .region = .JP, .script = null };
    pub const ko_KR = Locale{ .language = .ko, .region = .KR, .script = null };
    pub const ar_SA = Locale{ .language = .ar, .region = .SA, .script = null };
    pub const ru_RU = Locale{ .language = .ru, .region = .RU, .script = null };
    pub const hi_IN = Locale{ .language = .hi, .region = .IN, .script = null };

    pub fn init(language: LanguageCode, region: RegionCode) Locale {
        return .{
            .language = language,
            .region = region,
            .script = null,
        };
    }

    pub fn withScript(self: Locale, script: []const u8) Locale {
        var locale = self;
        locale.script = script;
        return locale;
    }

    pub fn textDirection(self: Locale) TextDirection {
        return TextDirection.forLanguage(self.language);
    }

    pub fn isRtl(self: Locale) bool {
        return self.textDirection().isRtl();
    }

    pub fn formatIdentifier(self: Locale, buf: []u8) []const u8 {
        const lang = self.language.toString();
        const reg = self.region.toString();
        const result = std.fmt.bufPrint(buf, "{s}_{s}", .{ lang, reg }) catch return "";
        return result;
    }
};

/// Plural category for grammatical number
pub const PluralCategory = enum {
    zero,
    one,
    two,
    few,
    many,
    other,

    pub fn toString(self: PluralCategory) []const u8 {
        return switch (self) {
            .zero => "zero",
            .one => "one",
            .two => "two",
            .few => "few",
            .many => "many",
            .other => "other",
        };
    }
};

/// Plural rules for different languages
pub const PluralRules = struct {
    language: LanguageCode,

    pub fn init(language: LanguageCode) PluralRules {
        return .{ .language = language };
    }

    pub fn select(self: PluralRules, count: i64) PluralCategory {
        const n = if (count < 0) -count else count;

        return switch (self.language) {
            // English, German, etc: 1 = one, else other
            .en, .de, .it, .nl, .sv, .da, .no, .fi, .es, .pt => {
                if (n == 1) return .one;
                return .other;
            },
            // French, Portuguese (Brazil): 0-1 = one, else other
            .fr => {
                if (n == 0 or n == 1) return .one;
                return .other;
            },
            // Arabic: complex rules
            .ar => {
                if (n == 0) return .zero;
                if (n == 1) return .one;
                if (n == 2) return .two;
                const mod100 = @mod(n, 100);
                if (mod100 >= 3 and mod100 <= 10) return .few;
                if (mod100 >= 11 and mod100 <= 99) return .many;
                return .other;
            },
            // Russian, Ukrainian: complex Slavic rules
            .ru, .uk => {
                const mod10 = @mod(n, 10);
                const mod100 = @mod(n, 100);
                if (mod10 == 1 and mod100 != 11) return .one;
                if (mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14)) return .few;
                return .many;
            },
            // Polish
            .pl => {
                if (n == 1) return .one;
                const mod10 = @mod(n, 10);
                const mod100 = @mod(n, 100);
                if (mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14)) return .few;
                return .many;
            },
            // Chinese, Japanese, Korean, Vietnamese, Thai, Indonesian: no plural
            .zh, .ja, .ko, .vi, .th, .id, .ms => .other,
            // Hebrew
            .he => {
                if (n == 1) return .one;
                if (n == 2) return .two;
                return .other;
            },
            // Czech
            .cs => {
                if (n == 1) return .one;
                if (n >= 2 and n <= 4) return .few;
                return .other;
            },
            else => {
                if (n == 1) return .one;
                return .other;
            },
        };
    }

    pub fn selectFloat(self: PluralRules, count: f64) PluralCategory {
        // For non-integer values, most languages use "other"
        const truncated = @as(i64, @intFromFloat(count));
        if (count != @as(f64, @floatFromInt(truncated))) {
            return .other;
        }
        return self.select(truncated);
    }
};

/// Number format style
pub const NumberStyle = enum {
    decimal,
    currency,
    percent,
    scientific,
    compact,

    pub fn toString(self: NumberStyle) []const u8 {
        return switch (self) {
            .decimal => "decimal",
            .currency => "currency",
            .percent => "percent",
            .scientific => "scientific",
            .compact => "compact",
        };
    }
};

/// Currency code (ISO 4217)
pub const CurrencyCode = enum {
    USD, // US Dollar
    EUR, // Euro
    GBP, // British Pound
    JPY, // Japanese Yen
    CNY, // Chinese Yuan
    KRW, // Korean Won
    INR, // Indian Rupee
    RUB, // Russian Ruble
    BRL, // Brazilian Real
    MXN, // Mexican Peso
    CAD, // Canadian Dollar
    AUD, // Australian Dollar
    CHF, // Swiss Franc
    SEK, // Swedish Krona
    NOK, // Norwegian Krone
    DKK, // Danish Krone
    PLN, // Polish Zloty
    TRY, // Turkish Lira
    SAR, // Saudi Riyal
    AED, // UAE Dirham
    ILS, // Israeli Shekel
    unknown,

    pub fn toString(self: CurrencyCode) []const u8 {
        return switch (self) {
            .USD => "USD",
            .EUR => "EUR",
            .GBP => "GBP",
            .JPY => "JPY",
            .CNY => "CNY",
            .KRW => "KRW",
            .INR => "INR",
            .RUB => "RUB",
            .BRL => "BRL",
            .MXN => "MXN",
            .CAD => "CAD",
            .AUD => "AUD",
            .CHF => "CHF",
            .SEK => "SEK",
            .NOK => "NOK",
            .DKK => "DKK",
            .PLN => "PLN",
            .TRY => "TRY",
            .SAR => "SAR",
            .AED => "AED",
            .ILS => "ILS",
            .unknown => "XXX",
        };
    }

    pub fn symbol(self: CurrencyCode) []const u8 {
        return switch (self) {
            .USD => "$",
            .EUR => "€",
            .GBP => "£",
            .JPY => "¥",
            .CNY => "¥",
            .KRW => "₩",
            .INR => "₹",
            .RUB => "₽",
            .BRL => "R$",
            .MXN => "$",
            .CAD => "$",
            .AUD => "$",
            .CHF => "CHF",
            .SEK => "kr",
            .NOK => "kr",
            .DKK => "kr",
            .PLN => "zł",
            .TRY => "₺",
            .SAR => "﷼",
            .AED => "د.إ",
            .ILS => "₪",
            .unknown => "¤",
        };
    }

    pub fn decimalPlaces(self: CurrencyCode) u8 {
        return switch (self) {
            .JPY, .KRW => 0, // No decimal places
            else => 2,
        };
    }

    pub fn forRegion(region: RegionCode) CurrencyCode {
        return switch (region) {
            .US => .USD,
            .GB => .GBP,
            .DE, .FR, .ES, .IT, .PT, .NL, .FI => .EUR,
            .JP => .JPY,
            .CN => .CNY,
            .KR => .KRW,
            .IN => .INR,
            .RU => .RUB,
            .BR => .BRL,
            .MX => .MXN,
            .CA => .CAD,
            .AU => .AUD,
            .SE => .SEK,
            .NO => .NOK,
            .DK => .DKK,
            .PL => .PLN,
            .TR => .TRY,
            .SA => .SAR,
            .AE => .AED,
            .IL => .ILS,
            else => .unknown,
        };
    }
};

/// Number format configuration
pub const NumberFormat = struct {
    style: NumberStyle,
    minimum_integer_digits: u8,
    minimum_fraction_digits: u8,
    maximum_fraction_digits: u8,
    use_grouping: bool,
    currency: CurrencyCode,

    pub fn decimal() NumberFormat {
        return .{
            .style = .decimal,
            .minimum_integer_digits = 1,
            .minimum_fraction_digits = 0,
            .maximum_fraction_digits = 3,
            .use_grouping = true,
            .currency = .unknown,
        };
    }

    pub fn forCurrency(code: CurrencyCode) NumberFormat {
        return .{
            .style = .currency,
            .minimum_integer_digits = 1,
            .minimum_fraction_digits = code.decimalPlaces(),
            .maximum_fraction_digits = code.decimalPlaces(),
            .use_grouping = true,
            .currency = code,
        };
    }

    pub fn percent() NumberFormat {
        return .{
            .style = .percent,
            .minimum_integer_digits = 1,
            .minimum_fraction_digits = 0,
            .maximum_fraction_digits = 0,
            .use_grouping = false,
            .currency = .unknown,
        };
    }

    pub fn withFractionDigits(self: NumberFormat, min: u8, max: u8) NumberFormat {
        var fmt = self;
        fmt.minimum_fraction_digits = min;
        fmt.maximum_fraction_digits = max;
        return fmt;
    }

    pub fn withGrouping(self: NumberFormat, enabled: bool) NumberFormat {
        var fmt = self;
        fmt.use_grouping = enabled;
        return fmt;
    }
};

/// Number formatting symbols for a locale
pub const NumberSymbols = struct {
    decimal_separator: u8,
    grouping_separator: u8,
    percent_sign: u8,
    minus_sign: u8,
    plus_sign: u8,

    pub const us_symbols = NumberSymbols{
        .decimal_separator = '.',
        .grouping_separator = ',',
        .percent_sign = '%',
        .minus_sign = '-',
        .plus_sign = '+',
    };

    pub const european_symbols = NumberSymbols{
        .decimal_separator = ',',
        .grouping_separator = '.',
        .percent_sign = '%',
        .minus_sign = '-',
        .plus_sign = '+',
    };

    pub const french_symbols = NumberSymbols{
        .decimal_separator = ',',
        .grouping_separator = ' ',
        .percent_sign = '%',
        .minus_sign = '-',
        .plus_sign = '+',
    };

    pub fn forLocale(locale: Locale) NumberSymbols {
        return switch (locale.language) {
            .en => us_symbols,
            .fr => french_symbols,
            .de, .es, .it, .pt, .nl, .pl, .ru, .tr => european_symbols,
            else => us_symbols,
        };
    }
};

/// Date format style
pub const DateStyle = enum {
    short_style, // 1/1/20
    medium_style, // Jan 1, 2020
    long_style, // January 1, 2020
    full_style, // Wednesday, January 1, 2020

    pub fn toString(self: DateStyle) []const u8 {
        return switch (self) {
            .short_style => "short",
            .medium_style => "medium",
            .long_style => "long",
            .full_style => "full",
        };
    }
};

/// Time format style
pub const TimeStyle = enum {
    short_style, // 3:30 PM
    medium_style, // 3:30:00 PM
    long_style, // 3:30:00 PM EST
    full_style, // 3:30:00 PM Eastern Standard Time

    pub fn toString(self: TimeStyle) []const u8 {
        return switch (self) {
            .short_style => "short",
            .medium_style => "medium",
            .long_style => "long",
            .full_style => "full",
        };
    }
};

/// Hour cycle preference
pub const HourCycle = enum {
    h12, // 1-12 with AM/PM
    h23, // 0-23
    h24, // 1-24
    h11, // 0-11 with AM/PM

    pub fn toString(self: HourCycle) []const u8 {
        return switch (self) {
            .h12 => "h12",
            .h23 => "h23",
            .h24 => "h24",
            .h11 => "h11",
        };
    }

    pub fn uses24Hour(self: HourCycle) bool {
        return self == .h23 or self == .h24;
    }

    pub fn forLocale(locale: Locale) HourCycle {
        return switch (locale.region) {
            .US, .CA, .AU, .IN => .h12,
            .GB => .h12,
            else => .h23,
        };
    }
};

/// Calendar type
pub const CalendarType = enum {
    gregorian,
    buddhist,
    chinese,
    hebrew,
    islamic,
    japanese,
    persian,

    pub fn toString(self: CalendarType) []const u8 {
        return switch (self) {
            .gregorian => "gregorian",
            .buddhist => "buddhist",
            .chinese => "chinese",
            .hebrew => "hebrew",
            .islamic => "islamic",
            .japanese => "japanese",
            .persian => "persian",
        };
    }

    pub fn forLocale(locale: Locale) CalendarType {
        return switch (locale.language) {
            .th => .buddhist,
            .he => .hebrew,
            .ar => .gregorian, // Default, but Islamic available
            .ja => .gregorian, // Japanese era calendar available
            else => .gregorian,
        };
    }
};

/// Day of week
pub const DayOfWeek = enum(u8) {
    sunday = 0,
    monday = 1,
    tuesday = 2,
    wednesday = 3,
    thursday = 4,
    friday = 5,
    saturday = 6,

    pub fn shortName(self: DayOfWeek, lang: LanguageCode) []const u8 {
        _ = lang; // Would vary by language
        return switch (self) {
            .sunday => "Sun",
            .monday => "Mon",
            .tuesday => "Tue",
            .wednesday => "Wed",
            .thursday => "Thu",
            .friday => "Fri",
            .saturday => "Sat",
        };
    }

    pub fn fullName(self: DayOfWeek, lang: LanguageCode) []const u8 {
        _ = lang; // Would vary by language
        return switch (self) {
            .sunday => "Sunday",
            .monday => "Monday",
            .tuesday => "Tuesday",
            .wednesday => "Wednesday",
            .thursday => "Thursday",
            .friday => "Friday",
            .saturday => "Saturday",
        };
    }

    pub fn firstDayOfWeek(locale: Locale) DayOfWeek {
        return switch (locale.region) {
            .US, .CA, .JP, .TW, .HK, .KR, .IL, .SA, .AE => .sunday,
            else => .monday,
        };
    }
};

/// Month
pub const Month = enum(u8) {
    january = 1,
    february = 2,
    march = 3,
    april = 4,
    may = 5,
    june = 6,
    july = 7,
    august = 8,
    september = 9,
    october = 10,
    november = 11,
    december = 12,

    pub fn shortName(self: Month, lang: LanguageCode) []const u8 {
        _ = lang;
        return switch (self) {
            .january => "Jan",
            .february => "Feb",
            .march => "Mar",
            .april => "Apr",
            .may => "May",
            .june => "Jun",
            .july => "Jul",
            .august => "Aug",
            .september => "Sep",
            .october => "Oct",
            .november => "Nov",
            .december => "Dec",
        };
    }

    pub fn fullName(self: Month, lang: LanguageCode) []const u8 {
        _ = lang;
        return switch (self) {
            .january => "January",
            .february => "February",
            .march => "March",
            .april => "April",
            .may => "May",
            .june => "June",
            .july => "July",
            .august => "August",
            .september => "September",
            .october => "October",
            .november => "November",
            .december => "December",
        };
    }

    pub fn daysInMonth(self: Month, is_leap_year: bool) u8 {
        return switch (self) {
            .january, .march, .may, .july, .august, .october, .december => 31,
            .april, .june, .september, .november => 30,
            .february => if (is_leap_year) 29 else 28,
        };
    }
};

/// Relative time unit
pub const RelativeTimeUnit = enum {
    second,
    minute,
    hour,
    day,
    week,
    month,
    quarter,
    year,

    pub fn toString(self: RelativeTimeUnit) []const u8 {
        return switch (self) {
            .second => "second",
            .minute => "minute",
            .hour => "hour",
            .day => "day",
            .week => "week",
            .month => "month",
            .quarter => "quarter",
            .year => "year",
        };
    }

    pub fn seconds(self: RelativeTimeUnit) u64 {
        return switch (self) {
            .second => 1,
            .minute => 60,
            .hour => 3600,
            .day => 86400,
            .week => 604800,
            .month => 2592000, // ~30 days
            .quarter => 7776000, // ~90 days
            .year => 31536000, // ~365 days
        };
    }
};

/// Measurement system
pub const MeasurementSystem = enum {
    metric,
    us_customary,
    uk_imperial,

    pub fn toString(self: MeasurementSystem) []const u8 {
        return switch (self) {
            .metric => "metric",
            .us_customary => "US",
            .uk_imperial => "UK",
        };
    }

    pub fn forLocale(locale: Locale) MeasurementSystem {
        return switch (locale.region) {
            .US => .us_customary,
            .GB => .uk_imperial,
            else => .metric,
        };
    }

    pub fn temperatureUnit(self: MeasurementSystem) []const u8 {
        return switch (self) {
            .metric => "°C",
            .us_customary => "°F",
            .uk_imperial => "°C",
        };
    }

    pub fn distanceUnit(self: MeasurementSystem) []const u8 {
        return switch (self) {
            .metric => "km",
            .us_customary => "mi",
            .uk_imperial => "mi",
        };
    }
};

/// Translation string entry
pub const TranslationEntry = struct {
    key: []const u8,
    value: []const u8,
    context: ?[]const u8,

    pub fn init(key: []const u8, value: []const u8) TranslationEntry {
        return .{
            .key = key,
            .value = value,
            .context = null,
        };
    }

    pub fn withContext(self: TranslationEntry, context: []const u8) TranslationEntry {
        var entry = self;
        entry.context = context;
        return entry;
    }
};

/// Localization manager
pub const LocalizationManager = struct {
    current_locale: Locale,
    fallback_locale: Locale,
    string_count: u32,
    missing_key_count: u32,

    pub fn init(locale: Locale) LocalizationManager {
        return .{
            .current_locale = locale,
            .fallback_locale = Locale.en_US,
            .string_count = 0,
            .missing_key_count = 0,
        };
    }

    pub fn setLocale(self: *LocalizationManager, locale: Locale) void {
        self.current_locale = locale;
    }

    pub fn setFallbackLocale(self: *LocalizationManager, locale: Locale) void {
        self.fallback_locale = locale;
    }

    pub fn registerStrings(self: *LocalizationManager, count: u32) void {
        self.string_count += count;
    }

    pub fn recordMissingKey(self: *LocalizationManager) void {
        self.missing_key_count += 1;
    }

    pub fn textDirection(self: LocalizationManager) TextDirection {
        return self.current_locale.textDirection();
    }

    pub fn pluralRules(self: LocalizationManager) PluralRules {
        return PluralRules.init(self.current_locale.language);
    }

    pub fn numberSymbols(self: LocalizationManager) NumberSymbols {
        return NumberSymbols.forLocale(self.current_locale);
    }

    pub fn hourCycle(self: LocalizationManager) HourCycle {
        return HourCycle.forLocale(self.current_locale);
    }

    pub fn measurementSystem(self: LocalizationManager) MeasurementSystem {
        return MeasurementSystem.forLocale(self.current_locale);
    }

    pub fn defaultCurrency(self: LocalizationManager) CurrencyCode {
        return CurrencyCode.forRegion(self.current_locale.region);
    }

    pub fn firstDayOfWeek(self: LocalizationManager) DayOfWeek {
        return DayOfWeek.firstDayOfWeek(self.current_locale);
    }
};

/// Get system locale (stub)
pub fn systemLocale() Locale {
    return Locale.en_US; // Would use platform APIs
}

/// Check if locale is supported
pub fn isLocaleSupported(locale: Locale) bool {
    return locale.language != .unknown;
}

// ============================================================================
// Tests
// ============================================================================

test "LanguageCode toString" {
    try std.testing.expectEqualStrings("en", LanguageCode.en.toString());
    try std.testing.expectEqualStrings("ja", LanguageCode.ja.toString());
    try std.testing.expectEqualStrings("ar", LanguageCode.ar.toString());
}

test "LanguageCode englishName" {
    try std.testing.expectEqualStrings("English", LanguageCode.en.englishName());
    try std.testing.expectEqualStrings("Japanese", LanguageCode.ja.englishName());
    try std.testing.expectEqualStrings("Arabic", LanguageCode.ar.englishName());
}

test "LanguageCode fromString" {
    try std.testing.expectEqual(LanguageCode.en, LanguageCode.fromString("en"));
    try std.testing.expectEqual(LanguageCode.fr, LanguageCode.fromString("fr"));
    try std.testing.expectEqual(LanguageCode.unknown, LanguageCode.fromString("xx"));
}

test "RegionCode properties" {
    try std.testing.expectEqualStrings("US", RegionCode.US.toString());
    try std.testing.expectEqualStrings("United States", RegionCode.US.englishName());
    try std.testing.expectEqualStrings("Japan", RegionCode.JP.englishName());
}

test "TextDirection forLanguage" {
    try std.testing.expectEqual(TextDirection.ltr, TextDirection.forLanguage(.en));
    try std.testing.expectEqual(TextDirection.ltr, TextDirection.forLanguage(.fr));
    try std.testing.expectEqual(TextDirection.rtl, TextDirection.forLanguage(.ar));
    try std.testing.expectEqual(TextDirection.rtl, TextDirection.forLanguage(.he));
}

test "TextDirection isRtl" {
    try std.testing.expect(!TextDirection.ltr.isRtl());
    try std.testing.expect(TextDirection.rtl.isRtl());
}

test "Locale presets" {
    try std.testing.expectEqual(LanguageCode.en, Locale.en_US.language);
    try std.testing.expectEqual(RegionCode.US, Locale.en_US.region);
    try std.testing.expectEqual(LanguageCode.ja, Locale.ja_JP.language);
}

test "Locale textDirection" {
    try std.testing.expectEqual(TextDirection.ltr, Locale.en_US.textDirection());
    try std.testing.expectEqual(TextDirection.rtl, Locale.ar_SA.textDirection());
}

test "Locale formatIdentifier" {
    var buf: [16]u8 = undefined;
    const id = Locale.en_US.formatIdentifier(&buf);
    try std.testing.expectEqualStrings("en_US", id);
}

test "PluralRules English" {
    const rules = PluralRules.init(.en);
    try std.testing.expectEqual(PluralCategory.one, rules.select(1));
    try std.testing.expectEqual(PluralCategory.other, rules.select(0));
    try std.testing.expectEqual(PluralCategory.other, rules.select(2));
    try std.testing.expectEqual(PluralCategory.other, rules.select(5));
}

test "PluralRules French" {
    const rules = PluralRules.init(.fr);
    try std.testing.expectEqual(PluralCategory.one, rules.select(0));
    try std.testing.expectEqual(PluralCategory.one, rules.select(1));
    try std.testing.expectEqual(PluralCategory.other, rules.select(2));
}

test "PluralRules Arabic" {
    const rules = PluralRules.init(.ar);
    try std.testing.expectEqual(PluralCategory.zero, rules.select(0));
    try std.testing.expectEqual(PluralCategory.one, rules.select(1));
    try std.testing.expectEqual(PluralCategory.two, rules.select(2));
    try std.testing.expectEqual(PluralCategory.few, rules.select(5));
    try std.testing.expectEqual(PluralCategory.many, rules.select(11));
}

test "PluralRules Russian" {
    const rules = PluralRules.init(.ru);
    try std.testing.expectEqual(PluralCategory.one, rules.select(1));
    try std.testing.expectEqual(PluralCategory.one, rules.select(21));
    try std.testing.expectEqual(PluralCategory.few, rules.select(2));
    try std.testing.expectEqual(PluralCategory.few, rules.select(3));
    try std.testing.expectEqual(PluralCategory.many, rules.select(5));
    try std.testing.expectEqual(PluralCategory.many, rules.select(11));
}

test "PluralRules Chinese/Japanese" {
    const zh_rules = PluralRules.init(.zh);
    const ja_rules = PluralRules.init(.ja);

    try std.testing.expectEqual(PluralCategory.other, zh_rules.select(0));
    try std.testing.expectEqual(PluralCategory.other, zh_rules.select(1));
    try std.testing.expectEqual(PluralCategory.other, ja_rules.select(100));
}

test "PluralRules selectFloat" {
    const rules = PluralRules.init(.en);
    try std.testing.expectEqual(PluralCategory.one, rules.selectFloat(1.0));
    try std.testing.expectEqual(PluralCategory.other, rules.selectFloat(1.5));
}

test "CurrencyCode properties" {
    try std.testing.expectEqualStrings("USD", CurrencyCode.USD.toString());
    try std.testing.expectEqualStrings("$", CurrencyCode.USD.symbol());
    try std.testing.expectEqualStrings("€", CurrencyCode.EUR.symbol());
    try std.testing.expectEqualStrings("¥", CurrencyCode.JPY.symbol());
}

test "CurrencyCode decimalPlaces" {
    try std.testing.expectEqual(@as(u8, 2), CurrencyCode.USD.decimalPlaces());
    try std.testing.expectEqual(@as(u8, 0), CurrencyCode.JPY.decimalPlaces());
    try std.testing.expectEqual(@as(u8, 0), CurrencyCode.KRW.decimalPlaces());
}

test "CurrencyCode forRegion" {
    try std.testing.expectEqual(CurrencyCode.USD, CurrencyCode.forRegion(.US));
    try std.testing.expectEqual(CurrencyCode.EUR, CurrencyCode.forRegion(.DE));
    try std.testing.expectEqual(CurrencyCode.JPY, CurrencyCode.forRegion(.JP));
    try std.testing.expectEqual(CurrencyCode.GBP, CurrencyCode.forRegion(.GB));
}

test "NumberFormat presets" {
    const dec = NumberFormat.decimal();
    try std.testing.expectEqual(NumberStyle.decimal, dec.style);
    try std.testing.expect(dec.use_grouping);

    const curr = NumberFormat.forCurrency(.USD);
    try std.testing.expectEqual(NumberStyle.currency, curr.style);
    try std.testing.expectEqual(CurrencyCode.USD, curr.currency);

    const pct = NumberFormat.percent();
    try std.testing.expectEqual(NumberStyle.percent, pct.style);
}

test "NumberSymbols forLocale" {
    const us = NumberSymbols.forLocale(Locale.en_US);
    try std.testing.expectEqual(@as(u8, '.'), us.decimal_separator);
    try std.testing.expectEqual(@as(u8, ','), us.grouping_separator);

    const fr = NumberSymbols.forLocale(Locale.fr_FR);
    try std.testing.expectEqual(@as(u8, ','), fr.decimal_separator);
    try std.testing.expectEqual(@as(u8, ' '), fr.grouping_separator);
}

test "HourCycle forLocale" {
    try std.testing.expectEqual(HourCycle.h12, HourCycle.forLocale(Locale.en_US));
    try std.testing.expectEqual(HourCycle.h23, HourCycle.forLocale(Locale.de_DE));
    try std.testing.expectEqual(HourCycle.h23, HourCycle.forLocale(Locale.ja_JP));
}

test "HourCycle uses24Hour" {
    try std.testing.expect(!HourCycle.h12.uses24Hour());
    try std.testing.expect(HourCycle.h23.uses24Hour());
    try std.testing.expect(HourCycle.h24.uses24Hour());
}

test "CalendarType forLocale" {
    try std.testing.expectEqual(CalendarType.gregorian, CalendarType.forLocale(Locale.en_US));
    try std.testing.expectEqual(CalendarType.buddhist, CalendarType.forLocale(Locale.init(.th, .unknown)));
    try std.testing.expectEqual(CalendarType.hebrew, CalendarType.forLocale(Locale.init(.he, .IL)));
}

test "DayOfWeek names" {
    try std.testing.expectEqualStrings("Mon", DayOfWeek.monday.shortName(.en));
    try std.testing.expectEqualStrings("Monday", DayOfWeek.monday.fullName(.en));
}

test "DayOfWeek firstDayOfWeek" {
    try std.testing.expectEqual(DayOfWeek.sunday, DayOfWeek.firstDayOfWeek(Locale.en_US));
    try std.testing.expectEqual(DayOfWeek.monday, DayOfWeek.firstDayOfWeek(Locale.de_DE));
    try std.testing.expectEqual(DayOfWeek.monday, DayOfWeek.firstDayOfWeek(Locale.fr_FR));
}

test "Month names" {
    try std.testing.expectEqualStrings("Jan", Month.january.shortName(.en));
    try std.testing.expectEqualStrings("January", Month.january.fullName(.en));
}

test "Month daysInMonth" {
    try std.testing.expectEqual(@as(u8, 31), Month.january.daysInMonth(false));
    try std.testing.expectEqual(@as(u8, 28), Month.february.daysInMonth(false));
    try std.testing.expectEqual(@as(u8, 29), Month.february.daysInMonth(true));
    try std.testing.expectEqual(@as(u8, 30), Month.april.daysInMonth(false));
}

test "RelativeTimeUnit seconds" {
    try std.testing.expectEqual(@as(u64, 1), RelativeTimeUnit.second.seconds());
    try std.testing.expectEqual(@as(u64, 60), RelativeTimeUnit.minute.seconds());
    try std.testing.expectEqual(@as(u64, 3600), RelativeTimeUnit.hour.seconds());
    try std.testing.expectEqual(@as(u64, 86400), RelativeTimeUnit.day.seconds());
}

test "MeasurementSystem forLocale" {
    try std.testing.expectEqual(MeasurementSystem.us_customary, MeasurementSystem.forLocale(Locale.en_US));
    try std.testing.expectEqual(MeasurementSystem.uk_imperial, MeasurementSystem.forLocale(Locale.init(.en, .GB)));
    try std.testing.expectEqual(MeasurementSystem.metric, MeasurementSystem.forLocale(Locale.de_DE));
}

test "MeasurementSystem units" {
    try std.testing.expectEqualStrings("°F", MeasurementSystem.us_customary.temperatureUnit());
    try std.testing.expectEqualStrings("°C", MeasurementSystem.metric.temperatureUnit());
    try std.testing.expectEqualStrings("mi", MeasurementSystem.us_customary.distanceUnit());
    try std.testing.expectEqualStrings("km", MeasurementSystem.metric.distanceUnit());
}

test "TranslationEntry creation" {
    const entry = TranslationEntry.init("greeting", "Hello")
        .withContext("home_screen");

    try std.testing.expectEqualStrings("greeting", entry.key);
    try std.testing.expectEqualStrings("Hello", entry.value);
    try std.testing.expectEqualStrings("home_screen", entry.context.?);
}

test "LocalizationManager init" {
    const manager = LocalizationManager.init(Locale.en_US);
    try std.testing.expectEqual(LanguageCode.en, manager.current_locale.language);
    try std.testing.expectEqual(TextDirection.ltr, manager.textDirection());
}

test "LocalizationManager setLocale" {
    var manager = LocalizationManager.init(Locale.en_US);
    manager.setLocale(Locale.ar_SA);

    try std.testing.expectEqual(LanguageCode.ar, manager.current_locale.language);
    try std.testing.expectEqual(TextDirection.rtl, manager.textDirection());
}

test "LocalizationManager services" {
    const manager = LocalizationManager.init(Locale.en_US);

    try std.testing.expectEqual(HourCycle.h12, manager.hourCycle());
    try std.testing.expectEqual(MeasurementSystem.us_customary, manager.measurementSystem());
    try std.testing.expectEqual(CurrencyCode.USD, manager.defaultCurrency());
    try std.testing.expectEqual(DayOfWeek.sunday, manager.firstDayOfWeek());
}

test "LocalizationManager German" {
    const manager = LocalizationManager.init(Locale.de_DE);

    try std.testing.expectEqual(HourCycle.h23, manager.hourCycle());
    try std.testing.expectEqual(MeasurementSystem.metric, manager.measurementSystem());
    try std.testing.expectEqual(CurrencyCode.EUR, manager.defaultCurrency());
    try std.testing.expectEqual(DayOfWeek.monday, manager.firstDayOfWeek());
}

test "LocalizationManager registerStrings" {
    var manager = LocalizationManager.init(Locale.en_US);
    manager.registerStrings(100);
    manager.registerStrings(50);

    try std.testing.expectEqual(@as(u32, 150), manager.string_count);
}

test "systemLocale" {
    const locale = systemLocale();
    try std.testing.expectEqual(LanguageCode.en, locale.language);
}

test "isLocaleSupported" {
    try std.testing.expect(isLocaleSupported(Locale.en_US));
    try std.testing.expect(isLocaleSupported(Locale.ja_JP));

    const unsupported = Locale.init(.unknown, .unknown);
    try std.testing.expect(!isLocaleSupported(unsupported));
}
