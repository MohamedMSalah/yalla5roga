/// Group membership roles. Only [owner] and [member] are supported.
///
/// Unknown API values (including legacy `admin`) normalize to [member].
enum GroupRole {
  owner,
  member;

  static GroupRole fromApi(String? value) {
    if (value == owner.name) return owner;
    return member;
  }
}
