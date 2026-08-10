class TorBridges {
  static const String obfs4_1 = 'obfs4 193.11.166.194:27015 2D8EA8EA56D5644F4A5E0B309A4CEB5DECA57D68 cert=J/0GfP93B+8Z4H38jXoO0tX+O9K5VwU4nU9z7Fj68+F7g9nJz/1Z5b2t1T0b7Q1s0q3BVA iat-mode=0';
  
  static const String obfs4_2 = 'obfs4 154.35.175.225:5673 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1thESH7CVHXGAUKnNiQwgui/FWjzGgGQZcmKGARyicPQBKA iat-mode=0';
  
  static const String snowflake = 'snowflake 192.0.2.3:1 2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ front=cdn.sstatic.net ice=stun:stun.l.google.com:19302,stun:stun.voip.blackberry.com:3478 utls-imitate=hellorandom';

  // یه لیست از همه‌شون که راحت بتونیم تو UI نشون بدیم
  static List<Map<String, String>> getAllProfiles() {
    return [
      {'name': 'Tor Obfs4 - 1', 'config': obfs4_1, 'type': 'obfs4'},
      {'name': 'Tor Obfs4 - 2', 'config': obfs4_2, 'type': 'obfs4'},
      {'name': 'Tor Snowflake - Super Fast', 'config': snowflake, 'type': 'snowflake'},
    ];
  }
}
