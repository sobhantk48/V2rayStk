/// استفاده از Tor داخلی به‌جای پروکسی محلی
Map<String, dynamic> buildNativeTorOutbound(String tag) {
  return {
    'type': 'tor',  // نوع واقعی Tor در sing-box
    'tag': tag,
    'executable_path': '',  // embedded باشه خالی می‌مونه
    'data_directory': '/data/data/com.example.v2ray_stk/files/tor',
    'options': {
      'ClientOnly': 1,
      'GeoIPFile': '',  // از bundle استفاده می‌کنه
      'GeoIPv6File': '',
    },
  };
}
