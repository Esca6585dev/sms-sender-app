/// Where a set of groups comes from. Each source has its own controller
/// instance and its own storage, so Excel groups and server groups never mix.
enum GroupSource {
  /// Numbers imported from an `.xlsx` file (Groups tab).
  excel,

  /// Numbers loaded from the backend contact list (Send tab).
  server;

  String get storageKey => switch (this) {
        GroupSource.excel => 'sms_groups_v1',
        GroupSource.server => 'sms_groups_server_v1',
      };
}
