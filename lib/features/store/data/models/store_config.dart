class StoreConfig {
  final bool isStoreEnabled;
  final String? closureMessage;

  StoreConfig({
    required this.isStoreEnabled,
    this.closureMessage,
  });

  factory StoreConfig.fromMap(Map<String, dynamic> map) {
    return StoreConfig(
      isStoreEnabled: map['isStoreEnabled'] ?? true,
      closureMessage: map['closureMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isStoreEnabled': isStoreEnabled,
      'closureMessage': closureMessage,
    };
  }
}
