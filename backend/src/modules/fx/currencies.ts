/**
 * Every currency the app offers, with its ISO 4217 minor unit.
 *
 * Static and shipped with the app rather than derived from the rate feed. Two
 * reasons: a user must be able to pick their currency even when the feed is
 * unreachable, and a provider that briefly drops a currency must not make it
 * disappear from the settings of everyone already using it.
 *
 * Scope is "money people actually hold". Deliberately excluded:
 *   - fund and accounting units (BOV, CHE, CHW, COU, MXV, XDR) — nobody budgets
 *     in Mexican UDIs;
 *   - precious metals (XAU, XAG, XPT, XPD) and the test codes XTS/XXX;
 *   - currencies withdrawn from circulation (CUC, HRK, SLL, STD, VEF, ZWL),
 *     which the feed still carries but which cannot be spent;
 *   - cryptocurrencies. Amounts are stored to two decimals, so a BTC base
 *     currency would silently destroy value on every write.
 *
 * A few entries here are not in the rate feed (XCG, ZWG, VED, and the sterling
 * island pounds). That is handled rather than hidden: the API marks each one
 * `convertible`, so the picker can show it and explain that conversion is not
 * available yet instead of pretending the currency does not exist.
 *
 * [decimals] drives display. XOF and JPY have no minor unit, so "1 000 FCFA" is
 * right where "1 000,00 FCFA" is wrong; the Gulf dinars use three.
 */
export interface CurrencyInfo {
  code: string;
  name: string;
  /** ISO 4217 minor units — 0 for XOF/JPY, 3 for the Gulf dinars. */
  decimals: number;
  symbol?: string;
}

export const CURRENCIES: CurrencyInfo[] = [
  { code: 'AED', name: 'United Arab Emirates Dirham', decimals: 2, symbol: 'د.إ' },
  { code: 'AFN', name: 'Afghan Afghani', decimals: 2 },
  { code: 'ALL', name: 'Albanian Lek', decimals: 2 },
  { code: 'AMD', name: 'Armenian Dram', decimals: 2 },
  { code: 'ANG', name: 'Netherlands Antillean Guilder', decimals: 2 },
  { code: 'AOA', name: 'Angolan Kwanza', decimals: 2 },
  { code: 'ARS', name: 'Argentine Peso', decimals: 2, symbol: 'AR$' },
  { code: 'AUD', name: 'Australian Dollar', decimals: 2, symbol: 'A$' },
  { code: 'AWG', name: 'Aruban Florin', decimals: 2 },
  { code: 'AZN', name: 'Azerbaijani Manat', decimals: 2 },
  { code: 'BAM', name: 'Bosnia-Herzegovina Convertible Mark', decimals: 2 },
  { code: 'BBD', name: 'Barbadian Dollar', decimals: 2 },
  { code: 'BDT', name: 'Bangladeshi Taka', decimals: 2, symbol: '৳' },
  { code: 'BGN', name: 'Bulgarian Lev', decimals: 2 },
  { code: 'BHD', name: 'Bahraini Dinar', decimals: 3 },
  { code: 'BIF', name: 'Burundian Franc', decimals: 0 },
  { code: 'BMD', name: 'Bermudan Dollar', decimals: 2 },
  { code: 'BND', name: 'Brunei Dollar', decimals: 2 },
  { code: 'BOB', name: 'Bolivian Boliviano', decimals: 2 },
  { code: 'BRL', name: 'Brazilian Real', decimals: 2, symbol: 'R$' },
  { code: 'BSD', name: 'Bahamian Dollar', decimals: 2 },
  { code: 'BTN', name: 'Bhutanese Ngultrum', decimals: 2 },
  { code: 'BWP', name: 'Botswanan Pula', decimals: 2 },
  { code: 'BYN', name: 'Belarusian Ruble', decimals: 2 },
  { code: 'BZD', name: 'Belize Dollar', decimals: 2 },
  { code: 'CAD', name: 'Canadian Dollar', decimals: 2, symbol: 'CA$' },
  { code: 'CDF', name: 'Congolese Franc', decimals: 2 },
  { code: 'CHF', name: 'Swiss Franc', decimals: 2, symbol: 'CHF' },
  { code: 'CLP', name: 'Chilean Peso', decimals: 0, symbol: 'CLP$' },
  { code: 'CNY', name: 'Chinese Yuan', decimals: 2, symbol: '¥' },
  { code: 'COP', name: 'Colombian Peso', decimals: 2, symbol: 'COL$' },
  { code: 'CRC', name: 'Costa Rican Colón', decimals: 2 },
  { code: 'CUP', name: 'Cuban Peso', decimals: 2 },
  { code: 'CVE', name: 'Cape Verdean Escudo', decimals: 2 },
  { code: 'CZK', name: 'Czech Republic Koruna', decimals: 2, symbol: 'Kč' },
  { code: 'DJF', name: 'Djiboutian Franc', decimals: 0 },
  { code: 'DKK', name: 'Danish Krone', decimals: 2, symbol: 'kr' },
  { code: 'DOP', name: 'Dominican Peso', decimals: 2 },
  { code: 'DZD', name: 'Algerian Dinar', decimals: 2 },
  { code: 'EGP', name: 'Egyptian Pound', decimals: 2, symbol: 'E£' },
  { code: 'ERN', name: 'Eritrean Nakfa', decimals: 2 },
  { code: 'ETB', name: 'Ethiopian Birr', decimals: 2 },
  { code: 'EUR', name: 'Euro', decimals: 2, symbol: '€' },
  { code: 'FJD', name: 'Fijian Dollar', decimals: 2 },
  { code: 'FKP', name: 'Falkland Islands Pound', decimals: 2 },
  { code: 'GBP', name: 'British Pound Sterling', decimals: 2, symbol: '£' },
  { code: 'GEL', name: 'Georgian Lari', decimals: 2 },
  { code: 'GGP', name: 'Guernsey Pound', decimals: 2 },
  { code: 'GHS', name: 'Ghanaian Cedi', decimals: 2, symbol: '₵' },
  { code: 'GIP', name: 'Gibraltar Pound', decimals: 2 },
  { code: 'GMD', name: 'Gambian Dalasi', decimals: 2 },
  { code: 'GNF', name: 'Guinean Franc', decimals: 0 },
  { code: 'GTQ', name: 'Guatemalan Quetzal', decimals: 2 },
  { code: 'GYD', name: 'Guyanaese Dollar', decimals: 2 },
  { code: 'HKD', name: 'Hong Kong Dollar', decimals: 2, symbol: 'HK$' },
  { code: 'HNL', name: 'Honduran Lempira', decimals: 2 },
  { code: 'HTG', name: 'Haitian Gourde', decimals: 2 },
  { code: 'HUF', name: 'Hungarian Forint', decimals: 2, symbol: 'Ft' },
  { code: 'IDR', name: 'Indonesian Rupiah', decimals: 2, symbol: 'Rp' },
  { code: 'ILS', name: 'Israeli New Sheqel', decimals: 2, symbol: '₪' },
  { code: 'IMP', name: 'Isle of Man Pound', decimals: 2 },
  { code: 'INR', name: 'Indian Rupee', decimals: 2, symbol: '₹' },
  { code: 'IQD', name: 'Iraqi Dinar', decimals: 3 },
  { code: 'IRR', name: 'Iranian Rial', decimals: 2 },
  { code: 'ISK', name: 'Icelandic Króna', decimals: 0 },
  { code: 'JEP', name: 'Jersey Pound', decimals: 2 },
  { code: 'JMD', name: 'Jamaican Dollar', decimals: 2 },
  { code: 'JOD', name: 'Jordanian Dinar', decimals: 3 },
  { code: 'JPY', name: 'Japanese Yen', decimals: 0, symbol: '¥' },
  { code: 'KES', name: 'Kenyan Shilling', decimals: 2, symbol: 'KSh' },
  { code: 'KGS', name: 'Kyrgystani Som', decimals: 2 },
  { code: 'KHR', name: 'Cambodian Riel', decimals: 2 },
  { code: 'KMF', name: 'Comorian Franc', decimals: 0 },
  { code: 'KPW', name: 'North Korean Won', decimals: 2 },
  { code: 'KRW', name: 'South Korean Won', decimals: 0, symbol: '₩' },
  { code: 'KWD', name: 'Kuwaiti Dinar', decimals: 3 },
  { code: 'KYD', name: 'Cayman Islands Dollar', decimals: 2 },
  { code: 'KZT', name: 'Kazakhstani Tenge', decimals: 2 },
  { code: 'LAK', name: 'Laotian Kip', decimals: 2 },
  { code: 'LBP', name: 'Lebanese Pound', decimals: 2 },
  { code: 'LKR', name: 'Sri Lankan Rupee', decimals: 2, symbol: 'Rs' },
  { code: 'LRD', name: 'Liberian Dollar', decimals: 2 },
  { code: 'LSL', name: 'Lesotho Loti', decimals: 2 },
  { code: 'LYD', name: 'Libyan Dinar', decimals: 3 },
  { code: 'MAD', name: 'Moroccan Dirham', decimals: 2, symbol: 'DH' },
  { code: 'MDL', name: 'Moldovan Leu', decimals: 2 },
  { code: 'MGA', name: 'Malagasy Ariary', decimals: 2 },
  { code: 'MKD', name: 'Macedonian Denar', decimals: 2 },
  { code: 'MMK', name: 'Myanma Kyat', decimals: 2 },
  { code: 'MNT', name: 'Mongolian Tugrik', decimals: 2 },
  { code: 'MOP', name: 'Macanese Pataca', decimals: 2 },
  { code: 'MRU', name: 'Mauritanian Ouguiya', decimals: 2 },
  { code: 'MUR', name: 'Mauritian Rupee', decimals: 2 },
  { code: 'MVR', name: 'Maldivian Rufiyaa', decimals: 2 },
  { code: 'MWK', name: 'Malawian Kwacha', decimals: 2 },
  { code: 'MXN', name: 'Mexican Peso', decimals: 2, symbol: 'MX$' },
  { code: 'MYR', name: 'Malaysian Ringgit', decimals: 2, symbol: 'RM' },
  { code: 'MZN', name: 'Mozambican Metical', decimals: 2 },
  { code: 'NAD', name: 'Namibian Dollar', decimals: 2 },
  { code: 'NGN', name: 'Nigerian Naira', decimals: 2, symbol: '₦' },
  { code: 'NIO', name: 'Nicaraguan Córdoba', decimals: 2 },
  { code: 'NOK', name: 'Norwegian Krone', decimals: 2, symbol: 'kr' },
  { code: 'NPR', name: 'Nepalese Rupee', decimals: 2 },
  { code: 'NZD', name: 'New Zealand Dollar', decimals: 2, symbol: 'NZ$' },
  { code: 'OMR', name: 'Omani Rial', decimals: 3 },
  { code: 'PAB', name: 'Panamanian Balboa', decimals: 2 },
  { code: 'PEN', name: 'Peruvian Nuevo Sol', decimals: 2 },
  { code: 'PGK', name: 'Papua New Guinean Kina', decimals: 2 },
  { code: 'PHP', name: 'Philippine Peso', decimals: 2, symbol: '₱' },
  { code: 'PKR', name: 'Pakistani Rupee', decimals: 2, symbol: '₨' },
  { code: 'PLN', name: 'Polish Zloty', decimals: 2, symbol: 'zł' },
  { code: 'PYG', name: 'Paraguayan Guarani', decimals: 0 },
  { code: 'QAR', name: 'Qatari Rial', decimals: 2, symbol: '﷼' },
  { code: 'RON', name: 'Romanian Leu', decimals: 2 },
  { code: 'RSD', name: 'Serbian Dinar', decimals: 2 },
  { code: 'RUB', name: 'Russian Ruble', decimals: 2, symbol: '₽' },
  { code: 'RWF', name: 'Rwandan Franc', decimals: 0 },
  { code: 'SAR', name: 'Saudi Riyal', decimals: 2, symbol: '﷼' },
  { code: 'SBD', name: 'Solomon Islands Dollar', decimals: 2 },
  { code: 'SCR', name: 'Seychellois Rupee', decimals: 2 },
  { code: 'SDG', name: 'Sudanese Pound', decimals: 2 },
  { code: 'SEK', name: 'Swedish Krona', decimals: 2, symbol: 'kr' },
  { code: 'SGD', name: 'Singapore Dollar', decimals: 2, symbol: 'S$' },
  { code: 'SHP', name: 'Saint Helena Pound', decimals: 2 },
  { code: 'SLE', name: 'Sierra Leonean Leone', decimals: 2 },
  { code: 'SOS', name: 'Somali Shilling', decimals: 2 },
  { code: 'SRD', name: 'Surinamese Dollar', decimals: 2 },
  { code: 'SSP', name: 'South Sudanese Pound', decimals: 2 },
  { code: 'STN', name: 'São Tomé and Príncipe Dobra', decimals: 2 },
  { code: 'SVC', name: 'Salvadoran Colón', decimals: 2 },
  { code: 'SYP', name: 'Syrian Pound', decimals: 2 },
  { code: 'SZL', name: 'Swazi Lilangeni', decimals: 2 },
  { code: 'THB', name: 'Thai Baht', decimals: 2, symbol: '฿' },
  { code: 'TJS', name: 'Tajikistani Somoni', decimals: 2 },
  { code: 'TMT', name: 'Turkmenistani Manat', decimals: 2 },
  { code: 'TND', name: 'Tunisian Dinar', decimals: 3 },
  { code: 'TOP', name: "Tongan Pa'anga", decimals: 2 },
  { code: 'TRY', name: 'Turkish Lira', decimals: 2, symbol: '₺' },
  { code: 'TTD', name: 'Trinidad and Tobago Dollar', decimals: 2 },
  { code: 'TWD', name: 'New Taiwan Dollar', decimals: 2, symbol: 'NT$' },
  { code: 'TZS', name: 'Tanzanian Shilling', decimals: 2, symbol: 'TSh' },
  { code: 'UAH', name: 'Ukrainian Hryvnia', decimals: 2, symbol: '₴' },
  { code: 'UGX', name: 'Ugandan Shilling', decimals: 0, symbol: 'USh' },
  { code: 'USD', name: 'United States Dollar', decimals: 2, symbol: '$' },
  { code: 'UYU', name: 'Uruguayan Peso', decimals: 2 },
  { code: 'UZS', name: 'Uzbekistan Som', decimals: 2 },
  { code: 'VED', name: 'Venezuelan Bolívar', decimals: 2 },
  { code: 'VES', name: 'Venezuelan Bolívar Soberano', decimals: 2 },
  { code: 'VND', name: 'Vietnamese Dong', decimals: 0, symbol: '₫' },
  { code: 'VUV', name: 'Vanuatu Vatu', decimals: 0 },
  { code: 'WST', name: 'Samoan Tala', decimals: 2 },
  { code: 'XAF', name: 'CFA Franc BEAC', decimals: 0, symbol: 'FCFA' },
  { code: 'XCD', name: 'East Caribbean Dollar', decimals: 2, symbol: 'EC$' },
  { code: 'XCG', name: 'Caribbean Guilder', decimals: 2 },
  { code: 'XOF', name: 'CFA Franc BCEAO', decimals: 0, symbol: 'FCFA' },
  { code: 'XPF', name: 'CFP Franc', decimals: 0, symbol: 'CFP' },
  { code: 'YER', name: 'Yemeni Rial', decimals: 2 },
  { code: 'ZAR', name: 'South African Rand', decimals: 2, symbol: 'R' },
  { code: 'ZMW', name: 'Zambian Kwacha', decimals: 2 },
  { code: 'ZWG', name: 'Zimbabwe Gold', decimals: 2 },
];

export const CURRENCY_BY_CODE = new Map(CURRENCIES.map((c) => [c.code, c]));

/** Guards user input before it reaches a settings row or a transaction. */
export function isKnownCurrency(code: string | undefined | null): boolean {
  return !!code && CURRENCY_BY_CODE.has(code.toUpperCase());
}

/** Minor units for a code, defaulting to 2 for anything unrecognised. */
export function currencyDecimals(code: string): number {
  return CURRENCY_BY_CODE.get(code?.toUpperCase())?.decimals ?? 2;
}
